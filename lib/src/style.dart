// Recipe defaults, presets, palettes and the Material color-scheme mapping
// adapted from SeaGlassStyle.kt, SeaGlassTheme.kt and SeaGlassMaterialTheme.kt of
// Sea Glass for Compose by Matt McKenna
// (https://github.com/mttmcknn/sea-glass), licensed under Apache-2.0.
// Modified for Flutter by Omer Jahangir, 2026.

import 'package:flutter/material.dart';

import 'theme.dart';

/// The material recipe: how cloudy, grainy, wonky, thick and lit a piece is.
///
/// Lengths are logical pixels. Values outside the documented ranges are
/// clamped when the material is drawn.
@immutable
class SeaGlassStyle {
  /// Creates a material recipe. The defaults match [SeaGlassStyle.reference].
  const SeaGlassStyle({
    this.frost = 0.55,
    this.grain = 0.48,
    this.tumble = 0.025,
    this.thickness = 6,
    this.bulge = 0.65,
    this.elevation = 8,
    this.lightDegrees = 315,
    this.transmission = 0.58,
    this.seed = 42,
  });

  /// The reference recipe from the original playground.
  static const SeaGlassStyle reference = SeaGlassStyle();

  /// A heavily worn, wonky piece with deep frost.
  static const SeaGlassStyle tumbled = SeaGlassStyle(
    frost: 0.72,
    grain: 0.68,
    tumble: 0.055,
    thickness: 9,
    bulge: 0.80,
    elevation: 7,
    transmission: 0.48,
  );

  /// A calm, thin, nearly regular piece.
  static const SeaGlassStyle quiet = SeaGlassStyle(
    frost: 0.38,
    grain: 0.23,
    tumble: 0.012,
    thickness: 3,
    bulge: 0.38,
    elevation: 4,
    transmission: 0.66,
  );

  /// Cloudiness, 0..1.
  final double frost;

  /// Microscopic abrasion, 0..1.
  final double grain;

  /// Outline wobble as a fraction of the shorter side, 0..0.065.
  final double tumble;

  /// Optical thickness in logical pixels, 0..14.
  final double thickness;

  /// Curvature through the body, 0..1. Higher values read as a rounder pebble.
  final double bulge;

  /// Height of the fixed downward shadow in logical pixels, 0..18.
  final double elevation;

  /// Surface reflection azimuth in degrees. Zero is above, 90 is right.
  final double lightDegrees;

  /// Lower light exit and colored ground pool, 0..1.
  final double transmission;

  /// Stable piece identity. Two pieces with the same seed tumble identically.
  final int seed;

  /// Returns a copy with the given fields replaced.
  SeaGlassStyle copyWith({
    double? frost,
    double? grain,
    double? tumble,
    double? thickness,
    double? bulge,
    double? elevation,
    double? lightDegrees,
    double? transmission,
    int? seed,
  }) {
    return SeaGlassStyle(
      frost: frost ?? this.frost,
      grain: grain ?? this.grain,
      tumble: tumble ?? this.tumble,
      thickness: thickness ?? this.thickness,
      bulge: bulge ?? this.bulge,
      elevation: elevation ?? this.elevation,
      lightDegrees: lightDegrees ?? this.lightDegrees,
      transmission: transmission ?? this.transmission,
      seed: seed ?? this.seed,
    );
  }

  /// Returns this recipe with every value clamped to its documented range.
  SeaGlassStyle normalized() {
    return SeaGlassStyle(
      frost: frost.clamp(0.0, 1.0),
      grain: grain.clamp(0.0, 1.0),
      tumble: tumble.clamp(0.0, 0.065),
      thickness: thickness.clamp(0.0, 14.0),
      bulge: bulge.clamp(0.0, 1.0),
      elevation: elevation.clamp(0.0, 18.0),
      lightDegrees: lightDegrees.isFinite ? lightDegrees : 0,
      transmission: transmission.clamp(0.0, 1.0),
      seed: seed,
    );
  }

  /// Linearly interpolates between two recipes. The seed snaps at the midpoint.
  static SeaGlassStyle lerp(SeaGlassStyle a, SeaGlassStyle b, double t) {
    double mix(double x, double y) => x + (y - x) * t;
    return SeaGlassStyle(
      frost: mix(a.frost, b.frost),
      grain: mix(a.grain, b.grain),
      tumble: mix(a.tumble, b.tumble),
      thickness: mix(a.thickness, b.thickness),
      bulge: mix(a.bulge, b.bulge),
      elevation: mix(a.elevation, b.elevation),
      lightDegrees: mix(a.lightDegrees, b.lightDegrees),
      transmission: mix(a.transmission, b.transmission),
      seed: t < 0.5 ? a.seed : b.seed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SeaGlassStyle &&
      other.frost == frost &&
      other.grain == grain &&
      other.tumble == tumble &&
      other.thickness == thickness &&
      other.bulge == bulge &&
      other.elevation == elevation &&
      other.lightDegrees == lightDegrees &&
      other.transmission == transmission &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(
    frost,
    grain,
    tumble,
    thickness,
    bulge,
    elevation,
    lightDegrees,
    transmission,
    seed,
  );

  @override
  String toString() =>
      'SeaGlassStyle(frost: $frost, grain: $grain, '
      'tumble: $tumble, thickness: $thickness, bulge: $bulge, '
      'elevation: $elevation, lightDegrees: $lightDegrees, '
      'transmission: $transmission, seed: $seed)';
}

/// Body pigment, transmitted edge light, and a legible foreground color.
///
/// [body] and [edge] are treated as opaque pigments; their alpha is ignored.
/// [ink] keeps its alpha and is used for text and icons on the glass.
@immutable
class SeaGlassPalette {
  /// Creates a palette from explicit colors.
  const SeaGlassPalette({
    required this.body,
    required this.edge,
    required this.ink,
  });

  /// Soft blue.
  static const SeaGlassPalette lagoon = SeaGlassPalette(
    body: Color(0xFFB5D0EB),
    edge: Color(0xFFD6E9FF),
    ink: Color(0xFF2F647C),
  );

  /// Soft violet.
  static const SeaGlassPalette lilac = SeaGlassPalette(
    body: Color(0xFFE1CDE8),
    edge: Color(0xFFFBE8F7),
    ink: Color(0xFF71388B),
  );

  /// Soft pink.
  static const SeaGlassPalette rose = SeaGlassPalette(
    body: Color(0xFFEECED6),
    edge: Color(0xFFFFF0F1),
    ink: Color(0xFF963F59),
  );

  /// Soft honey.
  static const SeaGlassPalette amber = SeaGlassPalette(
    body: Color(0xFFF0D9BE),
    edge: Color(0xFFFFFCE0),
    ink: Color(0xFF865733),
  );

  /// Soft green.
  static const SeaGlassPalette mint = SeaGlassPalette(
    body: Color(0xFFC0DED0),
    edge: Color(0xFFE6FFF0),
    ink: Color(0xFF396C5A),
  );

  /// The five built-in pigments.
  static const List<SeaGlassPalette> values = [
    lagoon,
    lilac,
    rose,
    amber,
    mint,
  ];

  /// Body pigment.
  final Color body;

  /// Light that exits through the lower shoulder.
  final Color edge;

  /// Foreground color for content on the glass.
  final Color ink;

  /// Derives a palette from a Material 3 container/on-container pair.
  ///
  /// The edge is the container blended 35% toward white. Works with light,
  /// dark, seeded and dynamic schemes. The material transforms the pigment, so
  /// check contrast for your own colors.
  factory SeaGlassPalette.fromColorScheme(
    ColorScheme scheme, {
    SeaGlassColorRole role = SeaGlassColorRole.primary,
  }) {
    final (container, onContainer) = switch (role) {
      SeaGlassColorRole.primary => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      SeaGlassColorRole.secondary => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      SeaGlassColorRole.tertiary => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
    };
    final body = container.withValues(alpha: 1);
    return SeaGlassPalette(
      body: body,
      edge: Color.lerp(body, const Color(0xFFFFFFFF), 0.35)!,
      ink: onContainer,
    );
  }

  /// Returns a copy with the given fields replaced.
  SeaGlassPalette copyWith({Color? body, Color? edge, Color? ink}) {
    return SeaGlassPalette(
      body: body ?? this.body,
      edge: edge ?? this.edge,
      ink: ink ?? this.ink,
    );
  }

  /// Linearly interpolates between two palettes.
  static SeaGlassPalette lerp(SeaGlassPalette a, SeaGlassPalette b, double t) {
    return SeaGlassPalette(
      body: Color.lerp(a.body, b.body, t)!,
      edge: Color.lerp(a.edge, b.edge, t)!,
      ink: Color.lerp(a.ink, b.ink, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SeaGlassPalette &&
      other.body == body &&
      other.edge == edge &&
      other.ink == ink;

  @override
  int get hashCode => Object.hash(body, edge, ink);

  @override
  String toString() => 'SeaGlassPalette(body: $body, edge: $edge, ink: $ink)';
}

/// The base outline a piece is tumbled from.
enum SeaGlassShape {
  /// A worn rounded rectangle with nearly half-round corners.
  rounded,

  /// A stadium: fully round ends.
  capsule,

  /// An ellipse filling the bounds; a circle in a square.
  disc,
}

/// The Material 3 container/on-container pair used to color the glass.
enum SeaGlassColorRole {
  /// `primaryContainer` / `onPrimaryContainer`.
  primary,

  /// `secondaryContainer` / `onSecondaryContainer`.
  secondary,

  /// `tertiaryContainer` / `onTertiaryContainer`.
  tertiary,
}

/// A complete, reusable component look: recipe, pigment and outline.
///
/// Use it to share one look between several buttons or surfaces, or pass it to
/// [SeaGlassTheme.component].
@immutable
class SeaGlassComponentStyle {
  /// Creates a component style.
  const SeaGlassComponentStyle({
    this.material = SeaGlassStyle.reference,
    this.palette = SeaGlassPalette.lagoon,
    this.shape = SeaGlassShape.rounded,
  });

  /// The material recipe.
  final SeaGlassStyle material;

  /// The pigment.
  final SeaGlassPalette palette;

  /// The base outline.
  final SeaGlassShape shape;

  /// Gives this piece a stable identity while keeping the rest of the style.
  SeaGlassComponentStyle withSeed(int seed) =>
      copyWith(material: material.copyWith(seed: seed));

  /// Returns a copy with the given fields replaced.
  SeaGlassComponentStyle copyWith({
    SeaGlassStyle? material,
    SeaGlassPalette? palette,
    SeaGlassShape? shape,
  }) {
    return SeaGlassComponentStyle(
      material: material ?? this.material,
      palette: palette ?? this.palette,
      shape: shape ?? this.shape,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SeaGlassComponentStyle &&
      other.material == material &&
      other.palette == palette &&
      other.shape == shape;

  @override
  int get hashCode => Object.hash(material, palette, shape);
}
