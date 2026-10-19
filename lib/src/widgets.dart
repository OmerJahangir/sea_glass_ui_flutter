// Component API and behaviour (press offset, disabled alpha, focus ring)
// adapted from SeaGlass.kt of
// Sea Glass for Compose by Matt McKenna
// (https://github.com/mttmcknn/sea-glass), licensed under Apache-2.0.
// Modified for Flutter by Omer Jahangir, 2026.

import 'package:flutter/material.dart';

import 'render/render_sea_glass.dart';
import 'style.dart';
import 'theme.dart';

/// Draws sea glass behind [child].
///
/// The glass fills this widget's size; give the child padding for breathing
/// room. Shadow and transmitted light extend up to 48px outside the bounds, so
/// leave space around it or a clipping ancestor will crop them.
///
/// Adds no padding, input handling or semantics. The child is not clipped and
/// keeps its own colors; use [SeaGlassSurface] for clipping and ink colors.
class SeaGlass extends StatelessWidget {
  /// Creates sea glass behind [child]. Null values come from [SeaGlassTheme].
  const SeaGlass({super.key, this.style, this.palette, this.shape, this.child});

  /// Recipe, or null for the theme's.
  final SeaGlassStyle? style;

  /// Pigment, or null for the theme's.
  final SeaGlassPalette? palette;

  /// Outline, or null for the theme's.
  final SeaGlassShape? shape;

  /// Content drawn above the glass.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = SeaGlassTheme.of(context);
    return SeaGlassMaterial(
      style: style ?? theme.material,
      palette: palette ?? theme.palette,
      shape: shape ?? theme.shape,
      clipContent: false,
      child: child,
    );
  }
}

/// The low-level render widget behind every sea-glass component.
///
/// Prefer [SeaGlass], [SeaGlassSurface] or [SeaGlassButton].
class SeaGlassMaterial extends SingleChildRenderObjectWidget {
  /// Creates the material with fully resolved values.
  const SeaGlassMaterial({
    super.key,
    required this.style,
    required this.palette,
    required this.shape,
    this.clipContent = true,
    this.focusColor,
    super.child,
  });

  /// Recipe.
  final SeaGlassStyle style;

  /// Pigment.
  final SeaGlassPalette palette;

  /// Outline.
  final SeaGlassShape shape;

  /// Whether to clip [child] to the tumbled outline.
  final bool clipContent;

  /// When non-null, draws a 2px inner focus ring in this color.
  final Color? focusColor;

  @override
  RenderSeaGlass createRenderObject(BuildContext context) => RenderSeaGlass(
    style: style,
    palette: palette,
    shape: shape,
    clipContent: clipContent,
    focusColor: focusColor,
  );

  @override
  void updateRenderObject(BuildContext context, RenderSeaGlass renderObject) {
    renderObject
      ..style = style
      ..palette = palette
      ..shape = shape
      ..clipContent = clipContent
      ..focusColor = focusColor;
  }
}

/// Applies [palette]'s ink to text and icons below.
class _Ink extends StatelessWidget {
  const _Ink({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: TextStyle(color: color),
      child: IconTheme.merge(
        data: IconThemeData(color: color),
        child: child,
      ),
    );
  }
}

/// A content container made of sea glass.
///
/// Text and icons inside take the palette's ink color, and content is clipped
/// to the tumbled outline. The surface sizes to its child plus [padding].
class SeaGlassSurface extends StatelessWidget {
  /// Creates a surface. Null values come from [SeaGlassTheme].
  const SeaGlassSurface({
    super.key,
    this.style,
    this.palette,
    this.shape,
    this.component,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.center,
    this.child,
  });

  /// Recipe, or null for [component]'s or the theme's.
  final SeaGlassStyle? style;

  /// Pigment, or null for [component]'s or the theme's.
  final SeaGlassPalette? palette;

  /// Outline, or null for [component]'s or the theme's.
  final SeaGlassShape? shape;

  /// A complete reusable look. Explicit [style], [palette] and [shape] win.
  final SeaGlassComponentStyle? component;

  /// Space between the glass edge and [child].
  final EdgeInsetsGeometry padding;

  /// How [child] is placed when the surface is larger than it.
  final AlignmentGeometry alignment;

  /// The content.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final base = component ?? SeaGlassTheme.of(context);
    final resolvedPalette = palette ?? base.palette;
    return SeaGlassMaterial(
      style: style ?? base.material,
      palette: resolvedPalette,
      shape: shape ?? base.shape,
      child: _Ink(
        color: resolvedPalette.ink,
        child: Padding(
          padding: padding,
          child: Align(
            alignment: alignment,
            widthFactor: 1,
            heightFactor: 1,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// An accessible sea-glass button with a small physical press offset.
///
/// Set [onPressed] to null to disable it. Supports keyboard focus and
/// activation (Enter/Space), and is announced as a button.
class SeaGlassButton extends StatefulWidget {
  /// Creates a button. Null look values come from [SeaGlassTheme].
  const SeaGlassButton({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.style,
    this.palette,
    this.shape,
    this.component,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    this.minSize = const Size(48, 48),
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.tooltip,
    required this.child,
  });

  /// A button with a leading [icon] and a [label].
  factory SeaGlassButton.icon({
    Key? key,
    required VoidCallback? onPressed,
    required Widget icon,
    required Widget label,
    SeaGlassStyle? style,
    SeaGlassPalette? palette,
    SeaGlassShape? shape,
    SeaGlassComponentStyle? component,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 16,
    ),
    double gap = 8,
  }) {
    return SeaGlassButton(
      key: key,
      onPressed: onPressed,
      style: style,
      palette: palette,
      shape: shape,
      component: component,
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          SizedBox(width: gap),
          label,
        ],
      ),
    );
  }

  /// Called on tap or keyboard activation. Null disables the button.
  final VoidCallback? onPressed;

  /// Called on long press.
  final VoidCallback? onLongPress;

  /// Recipe, or null for [component]'s or the theme's.
  final SeaGlassStyle? style;

  /// Pigment, or null for [component]'s or the theme's.
  final SeaGlassPalette? palette;

  /// Outline, or null for [component]'s or the theme's.
  final SeaGlassShape? shape;

  /// A complete reusable look. Explicit [style], [palette] and [shape] win.
  final SeaGlassComponentStyle? component;

  /// Space between the glass edge and [child].
  final EdgeInsetsGeometry padding;

  /// Minimum tap target. Defaults to 48×48.
  final Size minSize;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Whether to request focus when first built.
  final bool autofocus;

  /// Accessible label for icon-only buttons.
  final String? semanticLabel;

  /// Optional tooltip, also used as the accessible label.
  final String? tooltip;

  /// The content, typically a [Text], an [Icon], or both in a [Row].
  final Widget child;

  /// Whether the button responds to input.
  bool get enabled => onPressed != null || onLongPress != null;

  @override
  State<SeaGlassButton> createState() => _SeaGlassButtonState();
}

class _SeaGlassButtonState extends State<SeaGlassButton> {
  bool _pressed = false;
  bool _focused = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _activate() => widget.onPressed?.call();

  @override
  void didUpdateWidget(SeaGlassButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.component ?? SeaGlassTheme.of(context);
    final palette = widget.palette ?? base.palette;
    final enabled = widget.enabled;

    Widget result = SeaGlassMaterial(
      style: widget.style ?? base.material,
      palette: palette,
      shape: widget.shape ?? base.shape,
      focusColor: _focused ? palette.ink.withValues(alpha: 0.65) : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.minSize.width,
          minHeight: widget.minSize.height,
        ),
        child: _Ink(
          color: palette.ink,
          child: Padding(
            padding: widget.padding,
            child: Align(widthFactor: 1, heightFactor: 1, child: widget.child),
          ),
        ),
      ),
    );

    result = Transform.translate(
      offset: Offset(0, _pressed ? 2 : 0),
      child: Opacity(opacity: enabled ? 1 : 0.45, child: result),
    );

    result = FocusableActionDetector(
      enabled: enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: widget.onPressed,
        onLongPress: widget.onLongPress,
        child: result,
      ),
    );

    result = Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? widget.tooltip,
      onTap: widget.onPressed,
      child: result,
    );

    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }
    return result;
  }
}
