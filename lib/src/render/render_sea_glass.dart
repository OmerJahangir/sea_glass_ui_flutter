import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../geometry/contour.dart';
import '../geometry/field.dart';
import '../geometry/random.dart';
import '../style.dart';
import 'geometry_cache.dart';

/// Loads the body shader once per process.
class SeaGlassShaderLoader {
  SeaGlassShaderLoader._();

  static const String _asset =
      'packages/flutter_sea_glass/shaders/sea_glass_body.frag';

  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram?>? _loading;
  static bool _failed = false;

  /// The loaded program, or null while loading or if unsupported.
  static ui.FragmentProgram? get program => _program;

  /// Whether loading failed; the gradient fallback is used permanently.
  static bool get failed => _failed;

  /// Starts loading if needed and completes with the program or null.
  static Future<ui.FragmentProgram?> load() {
    return _loading ??= ui.FragmentProgram.fromAsset(_asset).then(
      (program) => _program = program,
      onError: (Object error, StackTrace stack) {
        _failed = true;
        debugPrint('flutter_sea_glass: shader unavailable, using the '
            'gradient fallback ($error)');
        return null;
      },
    );
  }
}

ContourShape _contourShape(SeaGlassShape shape) => switch (shape) {
      SeaGlassShape.rounded => ContourShape.rounded,
      SeaGlassShape.capsule => ContourShape.capsule,
      SeaGlassShape.disc => ContourShape.disc,
    };

/// Builds the tumbled outline as a [Path] in local coordinates.
Path seaGlassOutline(Size size, SeaGlassShape shape, SeaGlassStyle style) {
  final normalized = style.normalized();
  final contour = buildContour(size.width, size.height, _contourShape(shape),
      normalized.tumble, normalized.seed);
  final segments = contourSegments(contour);
  final path = Path()..moveTo(segments.first.x0, segments.first.y0);
  for (final s in segments) {
    path.cubicTo(s.x1, s.y1, s.x2, s.y2, s.x3, s.y3);
  }
  return path..close();
}

/// Paints sea glass behind its child, optionally clipping the child to the
/// tumbled outline and drawing a focus ring.
class RenderSeaGlass extends RenderProxyBox {
  /// Creates the render object.
  RenderSeaGlass({
    required SeaGlassStyle style,
    required SeaGlassPalette palette,
    required SeaGlassShape shape,
    required bool clipContent,
    Color? focusColor,
    RenderBox? child,
  })  : _style = style.normalized(),
        _palette = palette,
        _shape = shape,
        _clipContent = clipContent,
        _focusColor = focusColor,
        super(child);

  SeaGlassStyle _style;
  SeaGlassStyle get style => _style;
  set style(SeaGlassStyle value) {
    final normalized = value.normalized();
    if (normalized == _style) return;
    _style = normalized;
    markNeedsPaint();
  }

  SeaGlassPalette _palette;
  SeaGlassPalette get palette => _palette;
  set palette(SeaGlassPalette value) {
    if (value == _palette) return;
    _palette = value;
    markNeedsPaint();
  }

  SeaGlassShape _shape;
  SeaGlassShape get shape => _shape;
  set shape(SeaGlassShape value) {
    if (value == _shape) return;
    _shape = value;
    markNeedsPaint();
  }

  bool _clipContent;
  bool get clipContent => _clipContent;
  set clipContent(bool value) {
    if (value == _clipContent) return;
    _clipContent = value;
    markNeedsPaint();
  }

  Color? _focusColor;
  Color? get focusColor => _focusColor;
  set focusColor(Color? value) {
    if (value == _focusColor) return;
    _focusColor = value;
    markNeedsPaint();
  }

  // Outline cache.
  Path? _path;
  Object? _pathKey;

  // Geometry: the displayed textures, plus the newest wanted request.
  GeometryTextures? _geometry;
  FieldRequest? _inFlight;
  FieldRequest? _wanted;

  ui.FragmentShader? _shader;
  bool _waitingForProgram = false;

  @override
  void detach() {
    _wanted = null;
    super.detach();
  }

  @override
  void dispose() {
    _geometry?.dispose();
    _geometry = null;
    _shader?.dispose();
    _shader = null;
    super.dispose();
  }

  // The material draws outside the layout bounds (shadow and light pool).
  @override
  Rect get paintBounds => (Offset.zero & size).inflate(48);

  Path _outline() {
    final key = (size, _shape, _style.tumble, _style.seed);
    if (_path == null || _pathKey != key) {
      _path = seaGlassOutline(size, _shape, _style);
      _pathKey = key;
    }
    return _path!;
  }

  FieldRequest _request() => FieldRequest(
        width: size.width,
        height: size.height,
        shape: _contourShape(_shape),
        tumble: _style.tumble,
        bulge: _style.bulge,
        seed: _style.seed,
      );

  /// Returns textures to draw now, requesting newer ones if needed. Keeps the
  /// last complete geometry on screen while a new one is prepared.
  GeometryTextures? _resolveGeometry() {
    final request = _request();
    if (_geometry?.request == request) return _geometry;
    final cached = GeometryCache.instance.lookup(request);
    if (cached != null) {
      _geometry?.dispose();
      _geometry = cached;
      return cached;
    }
    _wanted = request;
    _startBuild();
    return _geometry;
  }

  void _startBuild() {
    final request = _wanted;
    if (request == null || _inFlight != null) return;
    _inFlight = request;
    GeometryCache.instance.obtain(request).then((textures) {
      _inFlight = null;
      if (textures == null) return;
      if (!attached || _wanted == null) {
        textures.dispose();
        return;
      }
      if (_wanted == request) {
        _geometry?.dispose();
        _geometry = textures;
        _wanted = null;
        markNeedsPaint();
      } else {
        // A newer request arrived meanwhile. Show this one and build that.
        _geometry?.dispose();
        _geometry = textures;
        markNeedsPaint();
        _startBuild();
      }
    });
  }

  ui.FragmentShader? _resolveShader() {
    if (_shader != null) return _shader;
    final program = SeaGlassShaderLoader.program;
    if (program != null) return _shader = program.fragmentShader();
    if (!SeaGlassShaderLoader.failed && !_waitingForProgram) {
      _waitingForProgram = true;
      SeaGlassShaderLoader.load().then((_) {
        _waitingForProgram = false;
        if (attached) markNeedsPaint();
      });
    }
    return null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) {
      super.paint(context, offset);
      return;
    }
    final path = _outline();
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    _paintGround(canvas, path);
    _paintBody(canvas, path);
    canvas.restore();

    final focus = _focusColor;
    if (!_clipContent) {
      super.paint(context, offset);
      if (focus != null) _paintFocus(context.canvas, offset, path, focus);
      return;
    }
    context.pushClipPath(
      needsCompositing,
      offset,
      Offset.zero & size,
      path,
      (context, offset) {
        super.paint(context, offset);
        if (focus != null) _paintFocus(context.canvas, offset, path, focus);
      },
    );
  }

  void _paintFocus(Canvas canvas, Offset offset, Path path, Color color) {
    // A centered 4px stroke clipped to the outline reads as a 2px inner ring.
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = color,
    );
    canvas.restore();
  }

  /// Fixed downward cast and contact shadows plus the colored light pool.
  /// The scene light is overhead, so shadows never follow [lightDegrees].
  void _paintGround(Canvas canvas, Path path) {
    final s = _style;
    final short = math.min(size.width, size.height);
    final t = s.transmission;

    final castDrop =
        math.min(16.0, s.thickness * 0.40 + s.elevation * 0.72 + s.bulge * short * 0.03);
    final castBlur = math.min(
        6.0, 2.5 + s.elevation * 0.18 + s.frost * 0.7 + s.bulge * short * 0.018);
    canvas.drawPath(
      path.shift(Offset(0, castDrop)),
      Paint()
        ..color = Color.fromRGBO(63, 67, 66, (0.18 + s.elevation * 0.001) * (1 - t * 0.82))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, castBlur),
    );

    final contactDrop = math.min(8.0, s.thickness * 0.32 + 0.8);
    canvas.drawPath(
      path.shift(Offset(0, contactDrop)),
      Paint()
        ..color = Color.fromRGBO(61, 65, 63, 0.10 * (1 - t * 0.70))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.4 + s.elevation * 0.065),
    );

    if (t > 0.001) {
      final travel = 4 + s.elevation * 0.56 + short * 0.055;
      final drop = math.min(22.0, s.thickness * 0.42 + travel);
      final blur = math.min(8.0, 2.8 + short * 0.033 + s.frost * 1.6);
      final body = _palette.body;
      int boost(double channel) =>
          (255 - (255 - channel * 255) * 1.35).round().clamp(0, 255);
      final r = boost(body.r), g = boost(body.g), b = boost(body.b);
      canvas.drawPath(
        path.shift(Offset(0, drop)),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, drop),
            Offset(0, drop + size.height),
            [
              Color.fromRGBO(r, g, b, 0),
              Color.fromRGBO(r, g, b, t * 0.06),
              Color.fromRGBO(r, g, b, t * 0.48),
              Color.fromRGBO(r, g, b, t * 0.94),
            ],
            const [0, 0.45, 0.75, 1],
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }
  }

  void _paintBody(Canvas canvas, Path path) {
    final shader = _resolveShader();
    final geometry = _resolveGeometry();
    if (shader == null || geometry == null) {
      _paintFallbackBody(canvas, path);
      return;
    }
    final s = _style;
    final theta = s.lightDegrees * math.pi / 180;
    final lx = math.sin(theta), ly = -math.cos(theta);
    const lightZ = 0.52;
    final lightSide = math.sqrt(1 - lightZ * lightZ);
    final hx = lx * lightSide, hy = ly * lightSide, hz = lightZ + 1;
    final halfLength = math.sqrt(hx * hx + hy * hy + hz * hz);
    final body = _palette.body, edge = _palette.edge;

    var i = 0;
    void f(double v) => shader.setFloat(i++, v);
    f(size.width);
    f(size.height);
    f(s.frost);
    f(s.grain);
    f(s.thickness);
    f(s.bulge);
    f(geometry.slopeScale);
    f(s.transmission);
    f(_noiseSeed(s.seed));
    f(0);
    f(body.r);
    f(body.g);
    f(body.b);
    f(edge.r);
    f(edge.g);
    f(edge.b);
    f(lx);
    f(ly);
    f(hx / halfLength);
    f(hy / halfLength);
    f(hz / halfLength);
    shader.setImageSampler(0, geometry.imageA, filterQuality: FilterQuality.low);
    shader.setImageSampler(1, geometry.imageB, filterQuality: FilterQuality.low);

    canvas.drawPath(path, Paint()..shader = shader);
  }

  static final Map<int, double> _seedNoise = {};
  static double _noiseSeed(int seed) =>
      _seedNoise.putIfAbsent(seed, () => SeededRandom(seed).next());

  /// A gradient approximation used before the shader and geometry are ready,
  /// or where runtime shaders are unavailable.
  void _paintFallbackBody(Canvas canvas, Path path) {
    final s = _style;
    final body = _palette.body, edge = _palette.edge;
    Color absorb(double depth) {
      double channel(double b, double e) {
        final tint = b * 0.96 + e * 0.04;
        final absorbed = 1 - (1 - tint) * depth;
        return (absorbed + (1 - absorbed) * s.frost * 0.085).clamp(0.0, 1.0);
      }

      return Color.from(
        alpha: 1,
        red: channel(body.r, edge.r),
        green: channel(body.g, edge.g),
        blue: channel(body.b, edge.b),
      );
    }

    final core = absorb(1.12);
    const white = Color(0xFFFFFFFF);
    final top = Color.lerp(core, white, 0.10 + s.bulge * 0.14)!;
    final bottom = Color.lerp(core, edge.withValues(alpha: 1), 0.25 + s.transmission * 0.6)!;
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [top, core, core, bottom],
          const [0, 0.35, 0.7, 1],
        ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<SeaGlassStyle>('style', _style))
      ..add(DiagnosticsProperty<SeaGlassPalette>('palette', _palette))
      ..add(EnumProperty<SeaGlassShape>('shape', _shape))
      ..add(FlagProperty('clipContent', value: _clipContent, ifTrue: 'clips'))
      ..add(ColorProperty('focusColor', _focusColor, defaultValue: null));
  }
}
