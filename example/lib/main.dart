import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sea_glass_ui_flutter/sea_glass_ui_flutter.dart';

void main() => runApp(const SeaGlassExampleApp());

class SeaGlassExampleApp extends StatefulWidget {
  const SeaGlassExampleApp({super.key});

  @override
  State<SeaGlassExampleApp> createState() => _SeaGlassExampleAppState();
}

class _SeaGlassExampleAppState extends State<SeaGlassExampleApp> {
  Color? _materialYouSeed;

  @override
  Widget build(BuildContext context) {
    final seed = _materialYouSeed ?? const Color(0xFF5B8DB8);
    return MaterialApp(
      title: 'Sea Glass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF2F2EE),
      ),
      home: GalleryPage(
        materialYouSeed: _materialYouSeed,
        onMaterialYouSeed: (value) => setState(() => _materialYouSeed = value),
      ),
    );
  }
}

class GalleryPage extends StatelessWidget {
  const GalleryPage({
    super.key,
    required this.materialYouSeed,
    required this.onMaterialYouSeed,
  });

  final Color? materialYouSeed;
  final ValueChanged<Color?> onMaterialYouSeed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
          children: [
            Text(
              'SEA GLASS  /  FLUTTER',
              style: text.labelSmall?.copyWith(letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Sea glass, composed.',
              style: text.headlineMedium?.copyWith(fontFamily: 'serif'),
            ),
            const SizedBox(height: 4),
            Text(
              'Native Flutter content over a procedural material.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 24),
            const _Section(
              title: 'BUTTONS, A TOOLBAR, AND A PAIR OF PURE SURFACES',
              child: _Specimens(),
            ),
            const SizedBox(height: 20),
            const _Section(
              title: 'FIVE PIGMENTS. THE SAME MATERIAL.',
              child: _Pigments(),
            ),
            const SizedBox(height: 20),
            const _Section(
              title: 'EVERY SEED, A DIFFERENT PEBBLE.',
              child: _Pebbles(),
            ),
            const SizedBox(height: 20),
            const _Section(title: 'PLAYGROUND', child: _Playground()),
            const SizedBox(height: 20),
            _Section(
              title: 'MATERIAL YOU',
              child: _MaterialYou(
                seed: materialYouSeed,
                onSeed: onMaterialYouSeed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E0)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _Specimens extends StatelessWidget {
  const _Specimens();

  @override
  Widget build(BuildContext context) {
    final toolbar = SeaGlassComponentStyle(
      palette: SeaGlassPalette.lilac,
      shape: SeaGlassShape.capsule,
    );
    return Wrap(
      spacing: 24,
      runSpacing: 28,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SeaGlassSurface(
          component: toolbar,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final icon in [
                Icons.share_outlined,
                Icons.chat_outlined,
                Icons.download_outlined,
                Icons.edit_outlined,
                Icons.more_vert,
              ])
                IconButton(
                  onPressed: () {},
                  icon: Icon(icon, size: 20),
                  color: SeaGlassPalette.lilac.ink,
                ),
            ],
          ),
        ),
        SeaGlassButton(
          palette: SeaGlassPalette.rose,
          shape: SeaGlassShape.disc,
          padding: const EdgeInsets.all(14),
          tooltip: 'New',
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
        SeaGlassButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Compose', style: TextStyle(fontSize: 18)),
        ),
        const SeaGlassSurface(
          palette: SeaGlassPalette.mint,
          shape: SeaGlassShape.disc,
          child: SizedBox(width: 72, height: 72),
        ),
        const SeaGlassSurface(
          palette: SeaGlassPalette.mint,
          style: SeaGlassStyle(seed: 7),
          child: SizedBox(width: 140, height: 72),
        ),
      ],
    );
  }
}

class _Pigments extends StatelessWidget {
  const _Pigments();

  static const _names = ['Lagoon', 'Lilac', 'Rose', 'Amber', 'Mint'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 28,
      children: [
        for (var i = 0; i < SeaGlassPalette.values.length; i++)
          SeaGlassButton(
            palette: SeaGlassPalette.values[i],
            style: SeaGlassStyle(seed: 42 + i),
            onPressed: () {},
            child: Text(_names[i], style: const TextStyle(fontSize: 16)),
          ),
      ],
    );
  }
}

class _Pebbles extends StatelessWidget {
  const _Pebbles();

  @override
  Widget build(BuildContext context) {
    final shapes = [
      SeaGlassShape.disc,
      SeaGlassShape.rounded,
      SeaGlassShape.capsule,
    ];
    return Wrap(
      spacing: 20,
      runSpacing: 24,
      children: [
        for (var i = 0; i < 9; i++)
          SeaGlassSurface(
            palette: SeaGlassPalette.values[i % SeaGlassPalette.values.length],
            shape: shapes[i % shapes.length],
            style: SeaGlassStyle.tumbled.copyWith(seed: 11 + i * 37),
            child: SizedBox(
              width: shapes[i % shapes.length] == SeaGlassShape.disc ? 64 : 92,
              height: 64,
            ),
          ),
      ],
    );
  }
}

class _Playground extends StatefulWidget {
  const _Playground();

  @override
  State<_Playground> createState() => _PlaygroundState();
}

class _PlaygroundState extends State<_Playground> {
  SeaGlassStyle _style = SeaGlassStyle.reference;
  SeaGlassPalette _palette = SeaGlassPalette.lagoon;
  SeaGlassShape _shape = SeaGlassShape.rounded;
  final _random = math.Random();

  void _set(SeaGlassStyle style) => setState(() => _style = style);

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label)),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toStringAsFixed(max > 20 ? 0 : 2),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 140,
          child: Center(
            child: SeaGlassButton(
              style: s,
              palette: _palette,
              shape: _shape,
              padding: _shape == SeaGlassShape.disc
                  ? const EdgeInsets.all(28)
                  : const EdgeInsets.symmetric(horizontal: 40, vertical: 22),
              onPressed: () {},
              child: _shape == SeaGlassShape.disc
                  ? const Icon(Icons.water_drop_outlined, size: 32)
                  : const Text(
                      'Hello, sea glass',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final palette in SeaGlassPalette.values)
              ChoiceChip(
                showCheckmark: false,
                label: CircleAvatar(radius: 10, backgroundColor: palette.body),
                selected: palette == _palette,
                onSelected: (_) => setState(() => _palette = palette),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<SeaGlassShape>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: SeaGlassShape.rounded, label: Text('Rounded')),
            ButtonSegment(value: SeaGlassShape.capsule, label: Text('Capsule')),
            ButtonSegment(value: SeaGlassShape.disc, label: Text('Disc')),
          ],
          selected: {_shape},
          onSelectionChanged: (v) => setState(() => _shape = v.first),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _set(s.copyWith(seed: _random.nextInt(1 << 31))),
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Tumble'),
            ),
            for (final (name, preset) in [
              ('Reference', SeaGlassStyle.reference),
              ('Tumbled', SeaGlassStyle.tumbled),
              ('Quiet', SeaGlassStyle.quiet),
            ])
              OutlinedButton(
                onPressed: () => _set(preset.copyWith(seed: s.seed)),
                child: Text(name),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _slider('Frost', s.frost, 0, 1, (v) => _set(s.copyWith(frost: v))),
        _slider('Grain', s.grain, 0, 1, (v) => _set(s.copyWith(grain: v))),
        _slider(
          'Tumble',
          s.tumble,
          0,
          0.065,
          (v) => _set(s.copyWith(tumble: v)),
        ),
        _slider('Bulge', s.bulge, 0, 1, (v) => _set(s.copyWith(bulge: v))),
        _slider(
          'Thickness',
          s.thickness,
          0,
          14,
          (v) => _set(s.copyWith(thickness: v)),
        ),
        _slider(
          'Elevation',
          s.elevation,
          0,
          18,
          (v) => _set(s.copyWith(elevation: v)),
        ),
        _slider(
          'Transmission',
          s.transmission,
          0,
          1,
          (v) => _set(s.copyWith(transmission: v)),
        ),
        _slider(
          'Light',
          s.lightDegrees,
          0,
          360,
          (v) => _set(s.copyWith(lightDegrees: v)),
        ),
        Text('seed ${s.seed}', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MaterialYou extends StatelessWidget {
  const _MaterialYou({required this.seed, required this.onSeed});

  final Color? seed;
  final ValueChanged<Color?> onSeed;

  static const _seeds = [
    Color(0xFF5B8DB8),
    Color(0xFF8E5BB8),
    Color(0xFFB85B6E),
    Color(0xFFB8935B),
    Color(0xFF5BB88A),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final color in _seeds)
              ChoiceChip(
                showCheckmark: false,
                label: CircleAvatar(radius: 10, backgroundColor: color),
                selected: seed == color,
                onSelected: (_) => onSeed(color),
              ),
          ],
        ),
        const SizedBox(height: 24),
        SeaGlassMaterialTheme(
          style: SeaGlassStyle.tumbled,
          child: Wrap(
            spacing: 20,
            runSpacing: 28,
            children: [
              SeaGlassButton(onPressed: () {}, child: const Text('Primary')),
              SeaGlassMaterialTheme(
                role: SeaGlassColorRole.secondary,
                child: SeaGlassButton(
                  onPressed: () {},
                  child: const Text('Secondary'),
                ),
              ),
              SeaGlassMaterialTheme(
                role: SeaGlassColorRole.tertiary,
                child: SeaGlassButton(
                  onPressed: () {},
                  child: const Text('Tertiary'),
                ),
              ),
              SeaGlassButton(onPressed: null, child: const Text('Disabled')),
            ],
          ),
        ),
      ],
    );
  }
}
