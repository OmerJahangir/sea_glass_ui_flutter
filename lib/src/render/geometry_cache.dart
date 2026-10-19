import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../geometry/field.dart';

/// Decoded geometry textures for one [FieldRequest].
///
/// Each holder owns its own image handles; call [dispose] when done.
class GeometryTextures {
  GeometryTextures._(
    this.request,
    this.imageA,
    this.imageB,
    this.slopeScale,
    this.byteSize,
  );

  /// The request these textures were built for.
  final FieldRequest request;

  /// Slope X (16-bit) and dome.
  final ui.Image imageA;

  /// Slope Y (16-bit).
  final ui.Image imageB;

  /// Decode scale for the packed slopes.
  final double slopeScale;

  /// Approximate memory held.
  final int byteSize;

  /// Returns a new handle to the same textures.
  GeometryTextures clone() => GeometryTextures._(
    request,
    imageA.clone(),
    imageB.clone(),
    slopeScale,
    byteSize,
  );

  /// Releases this handle.
  void dispose() {
    imageA.dispose();
    imageB.dispose();
  }
}

/// Fields smaller than this are built on the UI isolate; spawning an isolate
/// would cost more than the work.
const int _syncSampleLimit = 24000;

PackedField _buildFieldEntry(FieldRequest request) => buildField(request);

/// A shared LRU of decoded geometry, keyed by quantized shape parameters.
///
/// Builds are coalesced: each [GeometryCache.obtain] caller keeps at most one
/// build in flight and remembers only the newest request, so dragging a slider
/// never queues a backlog.
class GeometryCache {
  GeometryCache._();

  /// The process-wide cache.
  static final GeometryCache instance = GeometryCache._();

  /// Maximum number of retained fields.
  static const int maxEntries = 32;

  /// Maximum retained texture bytes.
  static const int maxBytes = 4 * 1024 * 1024;

  final LinkedHashMap<FieldRequest, GeometryTextures> _entries =
      LinkedHashMap<FieldRequest, GeometryTextures>();
  final Map<FieldRequest, Future<GeometryTextures?>> _building = {};
  int _bytes = 0;

  /// Returns a new handle to cached textures for [request], or null.
  GeometryTextures? lookup(FieldRequest request) {
    final entry = _entries.remove(request);
    if (entry == null) return null;
    _entries[request] = entry; // Mark most recently used.
    return entry.clone();
  }

  /// Returns a future handle to textures for [request], building if needed.
  ///
  /// Completes with null if decoding fails.
  Future<GeometryTextures?> obtain(FieldRequest request) {
    final cached = lookup(request);
    if (cached != null) return SynchronousFuture(cached);
    final pending = _building[request] ??= _build(request);
    return pending.then((entry) => entry?.clone());
  }

  Future<GeometryTextures?> _build(FieldRequest request) async {
    try {
      final samples = request.width * request.height;
      final packed = samples <= _syncSampleLimit || kIsWeb
          ? buildField(request)
          : await compute(
              _buildFieldEntry,
              request,
              debugLabel: 'sea_glass_geometry',
            );
      final imageA = await _decode(packed.pixelsA, packed.width, packed.height);
      final imageB = await _decode(packed.pixelsB, packed.width, packed.height);
      final entry = GeometryTextures._(
        request,
        imageA,
        imageB,
        packed.slopeScale,
        packed.byteSize,
      );
      // Waiters clone this transfer handle, which outlives every microtask,
      // so a quick eviction from the cache cannot dispose it under them.
      final transfer = entry.clone();
      _insert(request, entry);
      Timer.run(() {
        _building.remove(request);
        transfer.dispose();
      });
      return transfer;
    } catch (error, stack) {
      Timer.run(() => _building.remove(request));
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'sea_glass_ui_flutter',
          context: ErrorDescription('while building sea glass geometry'),
        ),
      );
      return null;
    }
  }

  void _insert(FieldRequest request, GeometryTextures entry) {
    final old = _entries.remove(request);
    if (old != null) {
      _bytes -= old.byteSize;
      old.dispose();
    }
    _entries[request] = entry;
    _bytes += entry.byteSize;
    while (_entries.length > 1 &&
        (_entries.length > maxEntries || _bytes > maxBytes)) {
      final oldest = _entries.keys.first;
      final evicted = _entries.remove(oldest)!;
      _bytes -= evicted.byteSize;
      evicted.dispose();
    }
  }

  /// Drops every cached field. Handles held elsewhere stay valid.
  @visibleForTesting
  void clear() {
    for (final entry in _entries.values) {
      entry.dispose();
    }
    _entries.clear();
    _bytes = 0;
  }

  static Future<ui.Image> _decode(Uint8List pixels, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}
