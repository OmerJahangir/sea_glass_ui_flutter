// Geometry field ported from `getGeometryField`, `distanceLine`,
// `smoothHeight`, `noiseGrid` and the bulge blend in `prepareOptics`
// (web/dist/sea-glass.mjs) of
// Sea Glass for Compose by Matt McKenna
// (https://github.com/mttmcknn/sea-glass), licensed under Apache-2.0.
// Modified for Flutter by Omer Jahangir, 2026.

import 'dart:math' as math;
import 'dart:typed_data';

import 'contour.dart';
import 'random.dart';

/// Everything that determines a piece's smooth shape. Values are quantized so
/// equal-looking requests share one cached field.
class FieldRequest {
  /// Creates a request; dimensions are logical pixels.
  FieldRequest({
    required double width,
    required double height,
    required this.shape,
    required double tumble,
    required double bulge,
    required this.seed,
  }) : width = _q(width, 2),
       height = _q(height, 2),
       tumble = _q(tumble, 4),
       bulge = _q(bulge, 2);

  static double _q(double v, int digits) {
    final f = math.pow(10, digits);
    return (v * f).roundToDouble() / f;
  }

  /// Width in logical pixels.
  final double width;

  /// Height in logical pixels.
  final double height;

  /// Base outline.
  final ContourShape shape;

  /// Outline wobble, 0..0.065.
  final double tumble;

  /// Curvature blend between the flat-faced and round profiles, 0..1.
  final double bulge;

  /// Piece identity.
  final int seed;

  @override
  bool operator ==(Object other) =>
      other is FieldRequest &&
      other.width == width &&
      other.height == height &&
      other.shape == shape &&
      other.tumble == tumble &&
      other.bulge == bulge &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(width, height, shape, tumble, bulge, seed);
}

/// The packed geometry field, ready to upload as two RGBA textures.
///
/// Texture A holds the X slope as 16 bits (R high, G low) and the dome height
/// in B. Texture B holds the Y slope the same way. Slopes are encoded as
/// `0.5 + slope / (2 * slopeScale)`. Alpha is always opaque so premultiplied
/// uploads cannot alter the data.
class PackedField {
  /// Creates a packed field.
  const PackedField(
    this.width,
    this.height,
    this.slopeScale,
    this.pixelsA,
    this.pixelsB,
  );

  /// Texture width in samples.
  final int width;

  /// Texture height in samples.
  final int height;

  /// The largest absolute slope, used to decode the 16-bit values.
  final double slopeScale;

  /// RGBA8 bytes for texture A.
  final Uint8List pixelsA;

  /// RGBA8 bytes for texture B.
  final Uint8List pixelsB;

  /// Approximate memory held by the decoded textures.
  int get byteSize => pixelsA.length + pixelsB.length;
}

/// The largest number of samples a single field may use.
const int maxFieldSamples = 262144;

/// Bilinearly smoothed value noise on a seeded lattice.
class _NoiseGrid {
  _NoiseGrid(double width, double height, this.spacing, SeededRandom random)
    : columns = (width / spacing).ceil() + 2,
      rows = (height / spacing).ceil() + 2 {
    values = Float32List(columns * rows);
    for (var i = 0; i < values.length; i++) {
      values[i] = random.next() * 2 - 1;
    }
  }

  final double spacing;
  final int columns;
  final int rows;
  late final Float32List values;

  double sample(double x, double y) {
    final gx = x / spacing, gy = y / spacing;
    final ix = math.min(gx.floor(), columns - 2);
    final iy = math.min(gy.floor(), rows - 2);
    final tx = gx - ix, ty = gy - iy;
    final sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty);
    final a = values[iy * columns + ix], b = values[iy * columns + ix + 1];
    final c = values[(iy + 1) * columns + ix];
    final d = values[(iy + 1) * columns + ix + 1];
    return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy;
  }
}

/// Exact squared Euclidean distance transform along one line (Felzenszwalb).
void _distanceLine(
  Float64List input,
  int length,
  Float64List output,
  Int32List sites,
  Float64List separators,
) {
  var k = 0;
  sites[0] = 0;
  separators[0] = double.negativeInfinity;
  separators[1] = double.infinity;
  for (var q = 1; q < length; q++) {
    double cut;
    while (true) {
      final v = sites[k];
      cut = ((input[q] + q * q) - (input[v] + v * v)) / (2 * q - 2 * v);
      if (cut <= separators[k]) {
        k--;
        if (k < 0) break;
      } else {
        break;
      }
    }
    k++;
    sites[k] = q;
    separators[k] = cut;
    separators[k + 1] = double.infinity;
  }
  k = 0;
  for (var q = 0; q < length; q++) {
    while (separators[k + 1] < q) {
      k++;
    }
    final delta = q - sites[k];
    output[q] = (delta * delta) + input[sites[k]];
  }
}

/// Fills [mask] (1 inside, 0 outside) by even-odd scanline over a polygon.
///
/// Mask pixel `(mx, my)` samples material point
/// `((mx - 0.5) / scale, (my - 0.5) / scale)`, matching the original's one
/// pixel border around the texture.
void _rasterize(
  Uint8List mask,
  int columns,
  int rows,
  double scale,
  Float64List xs,
  Float64List ys,
) {
  final n = xs.length;
  final crossings = <double>[];
  for (var my = 0; my < rows; my++) {
    final y = (my - 0.5) / scale;
    crossings.clear();
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final yi = ys[i], yj = ys[j];
      if ((yi > y) != (yj > y)) {
        crossings.add(xs[i] + (y - yi) / (yj - yi) * (xs[j] - xs[i]));
      }
    }
    crossings.sort();
    for (var c = 0; c + 1 < crossings.length; c += 2) {
      final from = math.max(0, (crossings[c] * scale + 0.5).ceil());
      final to = math.min(
        columns - 1,
        (crossings[c + 1] * scale + 0.5).floor(),
      );
      for (var mx = from; mx <= to; mx++) {
        mask[my * columns + mx] = 1;
      }
    }
  }
}

Float32List _smoothHeight(
  Float32List values,
  int width,
  int height,
  double scale,
) {
  final sigma = 0.85 * scale;
  final reach = (sigma * 3).ceil();
  final weights = List<double>.generate(
    reach * 2 + 1,
    (i) => math.exp(-math.pow((i - reach) / sigma, 2) / 2),
  );
  final sum = weights.fold<double>(0, (t, v) => t + v);
  final horizontal = Float32List(values.length);
  final result = Float32List(values.length);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var value = 0.0;
      for (var k = -reach; k <= reach; k++) {
        value +=
            values[y * width + (x + k).clamp(0, width - 1)] *
            weights[k + reach];
      }
      horizontal[y * width + x] = value / sum;
    }
  }
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var value = 0.0;
      for (var k = -reach; k <= reach; k++) {
        value +=
            horizontal[(y + k).clamp(0, height - 1) * width + x] *
            weights[k + reach];
      }
      result[y * width + x] = value / sum;
    }
  }
  return result;
}

/// Samples per logical pixel for a field of this size.
double fieldScaleFor(double width, double height) {
  final area = math.max(1.0, width * height);
  return math.min(1.0, math.sqrt(maxFieldSamples / area));
}

/// Builds and packs the smooth geometry field for [request].
///
/// A port of the original `getGeometryField` plus the bulge blend from
/// `prepareOptics`. Pure Dart, so it can run on a background isolate.
PackedField buildField(FieldRequest request) {
  final w = math.max(1.0, request.width);
  final h = math.max(1.0, request.height);
  final scale = fieldScaleFor(w, h);
  final width = math.max(1, (w * scale).ceil());
  final height = math.max(1, (h * scale).ceil());
  final short = math.min(w, h);

  // Low-frequency clouds vary the shoulder width. The fine grids are skipped
  // so the random sequence matches the original texture order.
  final rand = SeededRandom(request.seed ^ 0x59BF1D7A);
  for (final spacing in const [0.68, 1.7]) {
    final columns = ((w + 3) / spacing).ceil() + 2;
    final rows = ((h + 3) / spacing).ceil() + 2;
    rand.skip(columns * rows);
  }
  final worn = _NoiseGrid(w + 3, h + 3, 7.5, rand);
  final cloud = _NoiseGrid(w + 3, h + 3, short * 0.44, rand);

  final contour = buildContour(
    w,
    h,
    request.shape,
    request.tumble,
    request.seed,
  );
  final (polyX, polyY) = flattenSegments(contourSegments(contour));

  final columns = width + 2, rows = height + 2;
  final mask = Uint8List(columns * rows);
  _rasterize(mask, columns, rows, scale, polyX, polyY);

  final distances = Float64List(columns * rows);
  for (var i = 0; i < distances.length; i++) {
    distances[i] = mask[i] == 1 ? 1e12 : 0;
  }
  final longest = math.max(columns, rows);
  final input = Float64List(longest), output = Float64List(longest);
  final sites = Int32List(longest), separators = Float64List(longest + 1);
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < columns; x++) {
      input[x] = distances[y * columns + x];
    }
    _distanceLine(input, columns, output, sites, separators);
    for (var x = 0; x < columns; x++) {
      distances[y * columns + x] = output[x];
    }
  }
  for (var x = 0; x < columns; x++) {
    for (var y = 0; y < rows; y++) {
      input[y] = distances[y * columns + x];
    }
    _distanceLine(input, rows, output, sites, separators);
    for (var y = 0; y < rows; y++) {
      distances[y * columns + x] =
          math.max(0.0, math.sqrt(output[y]) - 0.5) / scale;
    }
  }

  var maxDistance = 0.0;
  for (final d in distances) {
    if (d > maxDistance) maxDistance = d;
  }
  maxDistance = math.max(1.0, maxDistance);
  double at(int x, int y) =>
      distances[y.clamp(0, rows - 1) * columns + x.clamp(0, columns - 1)];

  final count = width * height;
  final profile = Float32List(count);
  final gradX = Float32List(count), gradY = Float32List(count);
  final roundProfile = Float32List(count);
  final roundGradX = Float32List(count), roundGradY = Float32List(count);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * width + x, mx = x + 1, my = y + 1;
      final cx = (x + 0.5) / scale, cy = (y + 0.5) / scale;
      final clouds = cloud.sample(cx, cy) * 0.75 + worn.sample(cx, cy) * 0.25;
      // An irregular broad shoulder flows into a largely flat face.
      final roll = short * (0.205 + clouds * 0.023);
      final d = at(mx, my);
      final dome = _tanh(d / roll);
      final slope = (1 - dome * dome) / roll;
      profile[i] = dome;
      final dx = at(mx + 2, my) - at(mx - 2, my);
      final dy = at(mx, my + 2) - at(mx, my - 2);
      final direction = math.sqrt(dx * dx + dy * dy);
      final hasDirection = direction > 0.001;
      gradX[i] = hasDirection ? dx / direction * slope : 0;
      gradY[i] = hasDirection ? dy / direction * slope : 0;
      // A semielliptical cross section turns all the way round the shoulder.
      final q = (d / maxDistance).clamp(0.0, 1.0);
      final arch = math.sqrt(q * (2 - q));
      final roundSlope = (1 - q) / (maxDistance * math.max(arch, 0.035));
      // A gentle lengthwise crown so long pieces are not plain extrusions.
      final u = (x + 0.5) / width;
      final su = math.sin(u * math.pi);
      final lengthArch = 0.86 + 0.14 * su * su;
      final lengthSlope = 0.14 * math.pi / w * math.sin(u * math.pi * 2);
      roundProfile[i] = arch * lengthArch;
      roundGradX[i] =
          (hasDirection ? dx / direction * roundSlope * lengthArch : 0) +
          arch * lengthSlope;
      roundGradY[i] = hasDirection
          ? dy / direction * roundSlope * lengthArch
          : 0;
    }
  }

  // Smooth geometry before differentiating, rather than blurring lit pixels.
  final softened = _smoothHeight(roundProfile, width, height, scale);
  double heightAt(int x, int y) =>
      softened[y.clamp(0, height - 1) * width + x.clamp(0, width - 1)];
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * width + x;
      final blend = ((at(x + 1, y + 1) - 2) / 3).clamp(0.0, 1.0);
      final weight = blend * blend * (3 - 2 * blend);
      roundProfile[i] += (softened[i] - roundProfile[i]) * weight;
      roundGradX[i] +=
          ((heightAt(x + 2, y) - heightAt(x - 2, y)) * scale / 4 -
              roundGradX[i]) *
          weight;
      roundGradY[i] +=
          ((heightAt(x, y + 2) - heightAt(x, y - 2)) * scale / 4 -
              roundGradY[i]) *
          weight;
    }
  }

  // Blend by bulge and pack.
  final bulge = request.bulge.clamp(0.0, 1.0);
  final dome = Float32List(count);
  final slopeX = Float32List(count), slopeY = Float32List(count);
  var slopeScale = 1e-6;
  for (var i = 0; i < count; i++) {
    dome[i] = profile[i] + (roundProfile[i] - profile[i]) * bulge;
    slopeX[i] = gradX[i] + (roundGradX[i] - gradX[i]) * bulge;
    slopeY[i] = gradY[i] + (roundGradY[i] - gradY[i]) * bulge;
    slopeScale = math.max(
      slopeScale,
      math.max(slopeX[i].abs(), slopeY[i].abs()),
    );
  }
  final pixelsA = Uint8List(count * 4);
  final pixelsB = Uint8List(count * 4);
  for (var i = 0; i < count; i++) {
    final p = i * 4;
    final qx = ((0.5 + slopeX[i] / (2 * slopeScale)) * 65535).round().clamp(
      0,
      65535,
    );
    final qy = ((0.5 + slopeY[i] / (2 * slopeScale)) * 65535).round().clamp(
      0,
      65535,
    );
    pixelsA[p] = qx >> 8;
    pixelsA[p + 1] = qx & 0xFF;
    pixelsA[p + 2] = (dome[i].clamp(0.0, 1.0) * 255).round();
    pixelsA[p + 3] = 255;
    pixelsB[p] = qy >> 8;
    pixelsB[p + 1] = qy & 0xFF;
    pixelsB[p + 2] = 0;
    pixelsB[p + 3] = 255;
  }
  return PackedField(width, height, slopeScale, pixelsA, pixelsB);
}

double _tanh(double x) {
  if (x > 20) return 1;
  if (x < -20) return -1;
  final e = math.exp(2 * x);
  return (e - 1) / (e + 1);
}
