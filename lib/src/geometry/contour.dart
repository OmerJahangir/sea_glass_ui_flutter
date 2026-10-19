import 'dart:math' as math;
import 'dart:typed_data';

import 'random.dart';

/// The base outline kinds, mirrored here so geometry stays free of `dart:ui`.
enum ContourShape { rounded, capsule, disc }

/// A closed outline as parallel coordinate arrays, in logical pixels.
class Contour {
  /// Creates a contour from parallel coordinate arrays.
  const Contour(this.xs, this.ys);

  /// X coordinates of the control points.
  final Float64List xs;

  /// Y coordinates of the control points.
  final Float64List ys;

  /// Number of control points.
  int get length => xs.length;
}

/// One cubic Bézier segment of the closed outline.
class ContourSegment {
  /// Creates a segment from its start, two controls and end point.
  const ContourSegment(
      this.x0, this.y0, this.x1, this.y1, this.x2, this.y2, this.x3, this.y3);

  /// Start point.
  final double x0, y0;

  /// First control point.
  final double x1, y1;

  /// Second control point.
  final double x2, y2;

  /// End point.
  final double x3, y3;
}

const double _tau = math.pi * 2;

/// Builds the seeded, tumbled outline for a [width] × [height] piece.
///
/// A port of the original `buildContour`: a rounded/capsule/disc base is
/// smoothed, pushed in and out along its normal by two low-frequency ripples,
/// then refitted to the layout bounds so touch geometry stays predictable.
Contour buildContour(
  double width,
  double height,
  ContourShape shape,
  double tumble,
  int seed, {
  int count = 160,
}) {
  final w = math.max(1.0, width);
  final h = math.max(1.0, height);
  final short = math.min(w, h);
  final amount = tumble.isFinite ? tumble.clamp(0.0, 0.065) : 0.0;
  final rand = SeededRandom(seed);
  final phase = [rand.next() * _tau, rand.next() * _tau, rand.next() * _tau];
  final strength = [0.70 + rand.next() * 0.10, 0.18 + rand.next() * 0.04];
  final samples = math.max(64, count);
  double ripple(double t) =>
      math.sin(t * 2 + phase[0]) * strength[0] +
      math.sin(t * 3 + phase[1]) * strength[1];

  // Nearly half-round corners make each piece a worn pebble rather than a
  // rounded box.
  final radius = shape == ContourShape.capsule ? short / 2 : short * 0.46;
  final arc = math.pi * radius / 2;
  final horizontal = math.max(0.0, w - radius * 2);
  final vertical = math.max(0.0, h - radius * 2);
  final lengths = [
    horizontal, arc, vertical, arc, horizontal, arc, vertical, arc //
  ];
  final perimeter = lengths.fold<double>(0, (sum, n) => sum + n);
  final centers = [
    [w - radius, radius],
    [w - radius, h - radius],
    [radius, h - radius],
    [radius, radius],
  ];

  final bx = Float64List(samples);
  final by = Float64List(samples);
  for (var i = 0; i < samples; i++) {
    final t = i / samples * _tau;
    double x = 0, y = 0;
    if (shape == ContourShape.disc) {
      final angle = t - math.pi / 2;
      x = w / 2 + math.cos(angle) * w / 2;
      y = h / 2 + math.sin(angle) * h / 2;
    } else {
      var distance = i / samples * perimeter;
      var segment = 0;
      while (segment < 7 && distance >= lengths[segment]) {
        distance -= lengths[segment];
        segment++;
      }
      final unit = lengths[segment] != 0 ? distance / lengths[segment] : 0.0;
      switch (segment) {
        case 0:
          x = radius + distance;
          y = 0;
        case 2:
          x = w;
          y = radius + distance;
        case 4:
          x = w - radius - distance;
          y = h;
        case 6:
          x = 0;
          y = h - radius - distance;
        default:
          final corner = (segment - 1) ~/ 2;
          final angle =
              -math.pi / 2 + corner * math.pi / 2 + unit * math.pi / 2;
          x = centers[corner][0] + math.cos(angle) * radius;
          y = centers[corner][1] + math.sin(angle) * radius;
      }
    }
    bx[i] = x;
    by[i] = y;
  }

  // Smooth the base before offsetting: a stadium's line/arc joins have
  // continuous tangents but discontinuous curvature.
  final a = w / 2, b = h / 2;
  final curveLength = shape == ContourShape.disc
      ? math.pi * (3 * (a + b) - math.sqrt((3 * a + b) * (a + 3 * b)))
      : perimeter;
  final sigma = math.max(0.7, short * 0.065 / (curveLength / samples));
  final reach = (sigma * 3).ceil();
  final weights = List<double>.generate(reach * 2 + 1,
      (i) => math.exp(-math.pow(i - reach, 2) / (2 * sigma * sigma)));
  final weightSum = weights.fold<double>(0, (s, n) => s + n);
  final sx = Float64List(samples);
  final sy = Float64List(samples);
  for (var i = 0; i < samples; i++) {
    double x = 0, y = 0;
    for (var k = 0; k < weights.length; k++) {
      final j = ((i + k - reach) % samples + samples) % samples;
      x += bx[j] * weights[k] / weightSum;
      y += by[j] * weights[k] / weightSum;
    }
    sx[i] = x;
    sy[i] = y;
  }

  final px = Float64List(samples);
  final py = Float64List(samples);
  var minX = double.infinity, maxX = -double.infinity;
  var minY = double.infinity, maxY = -double.infinity;
  for (var i = 0; i < samples; i++) {
    final prev = (i - 1 + samples) % samples;
    final next = (i + 1) % samples;
    final dx = sx[next] - sx[prev];
    final dy = sy[next] - sy[prev];
    final length = math.sqrt(dx * dx + dy * dy);
    final displacement = short * amount * ripple(i / samples * _tau);
    final x = sx[i] + dy / length * displacement;
    final y = sy[i] - dx / length * displacement;
    px[i] = x;
    py[i] = y;
    minX = math.min(minX, x);
    maxX = math.max(maxX, x);
    minY = math.min(minY, y);
    maxY = math.max(maxY, y);
  }

  // Fit the worn outline to its layout bounds.
  final inset = math.min(0.45, short * 0.005);
  for (var i = 0; i < samples; i++) {
    px[i] = inset + (px[i] - minX) / (maxX - minX) * (w - inset * 2);
    py[i] = inset + (py[i] - minY) / (maxY - minY) * (h - inset * 2);
  }
  return Contour(px, py);
}

/// Converts control points to a periodic uniform cubic B-spline.
///
/// This gives exact C2 continuity through the closing seam with no overshoot.
List<ContourSegment> contourSegments(Contour contour) {
  final n = contour.length;
  final xs = contour.xs, ys = contour.ys;
  return List<ContourSegment>.generate(n, (i) {
    final a = (i - 1 + n) % n, b = i, c = (i + 1) % n, d = (i + 2) % n;
    return ContourSegment(
      (xs[a] + 4 * xs[b] + xs[c]) / 6,
      (ys[a] + 4 * ys[b] + ys[c]) / 6,
      (2 * xs[b] + xs[c]) / 3,
      (2 * ys[b] + ys[c]) / 3,
      (xs[b] + 2 * xs[c]) / 3,
      (ys[b] + 2 * ys[c]) / 3,
      (xs[b] + 4 * xs[c] + xs[d]) / 6,
      (ys[b] + 4 * ys[c] + ys[d]) / 6,
    );
  }, growable: false);
}

/// Flattens the B-spline into a polygon with [steps] points per segment.
(Float64List, Float64List) flattenSegments(List<ContourSegment> segments,
    {int steps = 6}) {
  final count = segments.length * steps;
  final xs = Float64List(count);
  final ys = Float64List(count);
  var k = 0;
  for (final s in segments) {
    for (var j = 0; j < steps; j++) {
      final t = j / steps, u = 1 - t;
      final b0 = u * u * u, b1 = 3 * u * u * t, b2 = 3 * u * t * t;
      final b3 = t * t * t;
      xs[k] = b0 * s.x0 + b1 * s.x1 + b2 * s.x2 + b3 * s.x3;
      ys[k] = b0 * s.y0 + b1 * s.y1 + b2 * s.y2 + b3 * s.y3;
      k++;
    }
  }
  return (xs, ys);
}
