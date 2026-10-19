import 'package:flutter/material.dart';

import 'style.dart';

/// Sets sea-glass defaults for a subtree.
///
/// Omitted values inherit from the enclosing [SeaGlassTheme], so a nested
/// palette override keeps the parent's recipe and shape. Outside any theme the
/// reference recipe, [SeaGlassPalette.lagoon] and [SeaGlassShape.rounded] apply.
/// This widget adds no drawing or layout.
class SeaGlassTheme extends StatelessWidget {
  /// Overrides selected defaults; the rest are inherited.
  const SeaGlassTheme({
    super.key,
    this.style,
    this.palette,
    this.shape,
    required this.child,
  }) : component = null;

  /// Provides a complete reusable look. All three defaults come from
  /// [component].
  const SeaGlassTheme.component({
    super.key,
    required SeaGlassComponentStyle this.component,
    required this.child,
  })  : style = null,
        palette = null,
        shape = null;

  /// Recipe override, or null to inherit.
  final SeaGlassStyle? style;

  /// Pigment override, or null to inherit.
  final SeaGlassPalette? palette;

  /// Outline override, or null to inherit.
  final SeaGlassShape? shape;

  /// A complete look that replaces all inherited defaults.
  final SeaGlassComponentStyle? component;

  /// The subtree that receives these defaults.
  final Widget child;

  /// The resolved defaults for [context].
  static SeaGlassComponentStyle of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_SeaGlassScope>()
            ?.data ??
        const SeaGlassComponentStyle();
  }

  @override
  Widget build(BuildContext context) {
    final parent = of(context);
    final data = component ??
        SeaGlassComponentStyle(
          material: style ?? parent.material,
          palette: palette ?? parent.palette,
          shape: shape ?? parent.shape,
        );
    return _SeaGlassScope(data: data, child: child);
  }
}

class _SeaGlassScope extends InheritedWidget {
  const _SeaGlassScope({required this.data, required super.child});

  final SeaGlassComponentStyle data;

  @override
  bool updateShouldNotify(_SeaGlassScope oldWidget) => data != oldWidget.data;
}

/// Colors sea glass from the current Material 3 [ColorScheme].
///
/// Uses the [role]'s container color as pigment and its on-container color as
/// ink, so glass follows light/dark mode, seeded schemes and Android dynamic
/// color (when the app supplies a dynamic scheme to [ThemeData]). Omitted
/// [style] and [shape] inherit from the enclosing [SeaGlassTheme].
class SeaGlassMaterialTheme extends StatelessWidget {
  /// Creates a Material-driven sea-glass theme.
  const SeaGlassMaterialTheme({
    super.key,
    this.role = SeaGlassColorRole.primary,
    this.style,
    this.shape,
    required this.child,
  });

  /// Which container/on-container pair to use.
  final SeaGlassColorRole role;

  /// Recipe override, or null to inherit.
  final SeaGlassStyle? style;

  /// Outline override, or null to inherit.
  final SeaGlassShape? shape;

  /// The subtree that receives these defaults.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SeaGlassTheme(
      style: style,
      shape: shape,
      palette: SeaGlassPalette.fromColorScheme(scheme, role: role),
      child: child,
    );
  }
}
