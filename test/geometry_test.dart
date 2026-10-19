import 'package:flutter_sea_glass/src/geometry/contour.dart';
import 'package:flutter_sea_glass/src/geometry/field.dart';
import 'package:flutter_sea_glass/src/geometry/random.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixtures generated from the original web `sea-glass.mjs` with Node.
void main() {
  group('SeededRandom', () {
    test('matches the JavaScript mulberry32 sequence', () {
      final r = SeededRandom(42);
      const expected = [
        0.6011037519201636,
        0.44829055899754167,
        0.8524657934904099,
        0.6697340414393693,
        0.17481389874592423,
      ];
      for (final value in expected) {
        expect(r.next(), value);
      }
    });

    test('wraps negative seeds like >>> 0', () {
      final r = SeededRandom(-7);
      expect(r.next(), 0.43306733411736786);
      expect(r.next(), 0.32539576734416187);
      expect(r.next(), 0.5442695003002882);
    });
  });

  group('buildContour', () {
    void expectPoints(Contour c, List<List<double>> expected) {
      for (var k = 0; k < expected.length; k++) {
        final i = k * 40;
        expect(c.xs[i], closeTo(expected[k][0], 1e-9), reason: 'x[$i]');
        expect(c.ys[i], closeTo(expected[k][1], 1e-9), reason: 'y[$i]');
      }
    }

    test('rounded matches the reference', () {
      expectPoints(buildContour(200, 56, ContourShape.rounded, 0.025, 42), [
        [26.571452899044765, 2.1091386229348643],
        [142.61690761685318, 0.6151048650715856],
        [173.86883176909413, 54.10170236360068],
        [57.83367030943191, 55.28135953523156],
      ]);
    });

    test('disc matches the reference', () {
      expectPoints(buildContour(64, 64, ContourShape.disc, 0.055, 7), [
        [32.68939616894751, 0.997940708129682],
        [63.27940014791212, 32.50698785568252],
        [32.68939616894751, 63.49091234777603],
        [0.8035163669963599, 32.50698785568252],
      ]);
    });

    test('capsule matches the reference', () {
      expectPoints(buildContour(120, 48, ContourShape.capsule, 0.04, 1234), [
        [23.472021182884294, 1.4499863604867456],
        [98.8064550045372, 2.4187781001331645],
        [97.19363654150673, 47.05496300651134],
        [21.841824006650523, 45.281680202811735],
      ]);
    });

    test('stays inside its layout bounds', () {
      final c = buildContour(180, 60, ContourShape.rounded, 0.065, 99);
      for (var i = 0; i < c.length; i++) {
        expect(c.xs[i], inInclusiveRange(0, 180));
        expect(c.ys[i], inInclusiveRange(0, 60));
      }
    });
  });

  group('buildField', () {
    test('produces opaque textures with a raised middle', () {
      final field = buildField(FieldRequest(
        width: 120,
        height: 48,
        shape: ContourShape.rounded,
        tumble: 0.025,
        bulge: 0.65,
        seed: 42,
      ));
      expect(field.width, 120);
      expect(field.height, 48);
      expect(field.pixelsA.length, 120 * 48 * 4);
      for (var i = 3; i < field.pixelsA.length; i += 4) {
        expect(field.pixelsA[i], 255);
        expect(field.pixelsB[i], 255);
      }
      int dome(int x, int y) => field.pixelsA[(y * 120 + x) * 4 + 2];
      expect(dome(60, 24), greaterThan(200));
      expect(dome(0, 0), 0);
      expect(dome(60, 24), greaterThan(dome(60, 4)));
    });

    test('caps very large fields to the sample budget', () {
      final field = buildField(FieldRequest(
        width: 2000,
        height: 1000,
        shape: ContourShape.rounded,
        tumble: 0.02,
        bulge: 0.5,
        seed: 1,
      ));
      expect(field.width * field.height, lessThanOrEqualTo(maxFieldSamples + 2000));
    });

    test('equal requests are equal after quantization', () {
      FieldRequest make(double w) => FieldRequest(
          width: w,
          height: 40,
          shape: ContourShape.disc,
          tumble: 0.03,
          bulge: 0.6,
          seed: 3);
      expect(make(100.001), make(100.0));
      expect(make(100.2), isNot(make(100.0)));
    });
  });
}
