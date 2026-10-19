import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sea_glass/flutter_sea_glass.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('button calls onPressed and shows ink-colored text',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(SeaGlassButton(
      palette: SeaGlassPalette.rose,
      onPressed: () => taps++,
      child: const Text('Compose'),
    )));
    await tester.tap(find.text('Compose'));
    expect(taps, 1);

    final text = tester.widget<RichText>(
        find.descendant(of: find.text('Compose'), matching: find.byType(RichText)));
    expect(text.text.style?.color, SeaGlassPalette.rose.ink);
  });

  testWidgets('disabled button ignores taps and reports disabled',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const SeaGlassButton(
      onPressed: null,
      child: Text('Off'),
    )));
    await tester.tap(find.text('Off'), warnIfMissed: false);
    expect(
      tester.getSemantics(find.text('Off')),
      matchesSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        label: 'Off',
      ),
    );
    handle.dispose();
  });

  testWidgets('button activates from the keyboard', (tester) async {
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(_app(SeaGlassButton(
      focusNode: focus,
      onPressed: () => taps++,
      child: const Text('Go'),
    )));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('button meets the minimum tap target', (tester) async {
    await tester.pumpWidget(_app(SeaGlassButton(
      padding: EdgeInsets.zero,
      onPressed: () {},
      child: const SizedBox(width: 10, height: 10),
    )));
    final size = tester.getSize(find.byType(SeaGlassMaterial));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('nested themes inherit omitted values', (tester) async {
    late SeaGlassComponentStyle resolved;
    await tester.pumpWidget(_app(SeaGlassTheme(
      style: SeaGlassStyle.tumbled,
      shape: SeaGlassShape.capsule,
      child: SeaGlassTheme(
        palette: SeaGlassPalette.mint,
        child: Builder(builder: (context) {
          resolved = SeaGlassTheme.of(context);
          return const SizedBox();
        }),
      ),
    )));
    expect(resolved.material, SeaGlassStyle.tumbled);
    expect(resolved.shape, SeaGlassShape.capsule);
    expect(resolved.palette, SeaGlassPalette.mint);
  });

  testWidgets('material theme derives the palette from the color scheme',
      (tester) async {
    final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal));
    late SeaGlassPalette palette;
    await tester.pumpWidget(_app(
      SeaGlassMaterialTheme(
        role: SeaGlassColorRole.tertiary,
        child: Builder(builder: (context) {
          palette = SeaGlassTheme.of(context).palette;
          return const SizedBox();
        }),
      ),
      theme: theme,
    ));
    expect(palette.body, theme.colorScheme.tertiaryContainer);
    expect(palette.ink, theme.colorScheme.onTertiaryContainer);
  });

  testWidgets('surface and plain glass render and settle without errors',
      (tester) async {
    await tester.pumpWidget(_app(const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SeaGlassSurface(
          shape: SeaGlassShape.disc,
          child: SizedBox(width: 64, height: 64),
        ),
        SizedBox(height: 24),
        SeaGlass(
          palette: SeaGlassPalette.amber,
          child: Padding(padding: EdgeInsets.all(16), child: Text('Hello')),
        ),
      ],
    )));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Hello'), findsOneWidget);
  });

  test('style normalizes out-of-range values', () {
    const style = SeaGlassStyle(frost: 3, tumble: 1, elevation: -4);
    final n = style.normalized();
    expect(n.frost, 1);
    expect(n.tumble, 0.065);
    expect(n.elevation, 0);
  });

  test('outline fits its size', () {
    final path = seaGlassOutline(
        const Size(120, 48), SeaGlassShape.rounded, SeaGlassStyle.tumbled);
    final bounds = path.getBounds();
    expect(bounds.left, greaterThanOrEqualTo(0));
    expect(bounds.right, lessThanOrEqualTo(120.01));
    expect(bounds.bottom, lessThanOrEqualTo(48.01));
  });
}
