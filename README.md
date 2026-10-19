# flutter_sea_glass

Frosted color, softly tumbled edges, and a little seaside whimsy for Flutter.
Wrap any widget in sea glass, or use the ready-made buttons and surfaces.

A Flutter port of [Sea Glass for Compose](https://github.com/mttmcknn/sea-glass)
by Matt McKenna. The contour, geometry and lighting model follow the original.

<p>
  <img src="https://raw.githubusercontent.com/OmerJahangir/flutter_sea_glass/main/screenshots/01_gallery.png" width="260" alt="Sea glass buttons and surfaces">
  <img src="https://raw.githubusercontent.com/OmerJahangir/flutter_sea_glass/main/screenshots/03_playground.png" width="260" alt="Playground controls">
</p>
<p>
  <img src="https://raw.githubusercontent.com/OmerJahangir/flutter_sea_glass/main/screenshots/02_tumble.png" width="400" alt="Seeded tumbled pebbles">
  <img src="https://raw.githubusercontent.com/OmerJahangir/flutter_sea_glass/main/screenshots/04_material_you.png" width="400" alt="Material You glass">
</p>

## Install

```yaml
dependencies:
  flutter_sea_glass: ^0.1.0
```

## Add some glass

```dart
import 'package:flutter_sea_glass/flutter_sea_glass.dart';

SeaGlassButton(
  palette: SeaGlassPalette.lagoon,
  onPressed: () {},
  child: const Text('Hello, sea glass'),
)
```

Wrap anything:

```dart
SeaGlass(
  palette: SeaGlassPalette.mint,
  child: const Padding(
    padding: EdgeInsets.all(16),
    child: Text('Any widget'),
  ),
)
```

The glass draws its shadow and colored light pool up to 48px below and around
the widget, so leave some space or a clipping parent will crop it.

## Components

| Widget | What it does |
| --- | --- |
| `SeaGlass` | Draws glass behind any child. No padding, input or clipping. |
| `SeaGlassSurface` | A container: clips content to the outline and colors text/icons with the palette's ink. |
| `SeaGlassButton` | Accessible button with press offset, focus ring, keyboard activation and a 48×48 minimum target. `SeaGlassButton.icon` for icon + label. |

## Tumble

Every piece has a `seed`. The same seed always produces the same slightly wonky
outline; change it to tumble a new pebble.

```dart
SeaGlassButton(
  style: SeaGlassStyle.tumbled.copyWith(seed: 7),
  shape: SeaGlassShape.disc,
  onPressed: () {},
  child: const Icon(Icons.add),
)
```

`tumble` (0–0.065) controls how wonky the outline is.

## Styles

`SeaGlassStyle` is the material recipe:

| Field | Range | Meaning |
| --- | --- | --- |
| `frost` | 0–1 | Cloudiness |
| `grain` | 0–1 | Microscopic abrasion |
| `tumble` | 0–0.065 | Outline wobble |
| `thickness` | 0–14 | Optical thickness (px) |
| `bulge` | 0–1 | How round the body is |
| `elevation` | 0–18 | Shadow height (px) |
| `lightDegrees` | any | Reflection direction; 0 is above |
| `transmission` | 0–1 | Light exiting the bottom edge and the colored pool |
| `seed` | any int | Piece identity |

Presets: `SeaGlassStyle.reference`, `.tumbled`, `.quiet`.

Palettes: `SeaGlassPalette.lagoon`, `.lilac`, `.rose`, `.amber`, `.mint`, or
your own `SeaGlassPalette(body:, edge:, ink:)`.

Shapes: `SeaGlassShape.rounded`, `.capsule`, `.disc`.

`SeaGlassComponentStyle` bundles recipe, palette and shape so one look can be
shared between widgets.

## Themes

```dart
SeaGlassTheme(
  style: SeaGlassStyle.quiet,
  shape: SeaGlassShape.capsule,
  child: SeaGlassTheme(
    palette: SeaGlassPalette.rose, // inherits quiet + capsule
    child: ...,
  ),
)
```

### Material You

`SeaGlassMaterialTheme` takes pigment and ink from the current `ColorScheme`
(primary, secondary or tertiary container), so glass follows light/dark mode,
seeded schemes and dynamic color:

```dart
SeaGlassMaterialTheme(
  role: SeaGlassColorRole.tertiary,
  child: SeaGlassButton(onPressed: () {}, child: const Text('Go')),
)
```

Or build a palette directly with `SeaGlassPalette.fromColorScheme(scheme)`.

## How it renders

- **Outline:** a seeded contour (Mulberry32 random, two sine ripples),
  smoothed into a periodic cubic B-spline. The Dart port matches the original
  JavaScript output exactly.
- **Geometry:** a distance transform of the outline becomes a height field
  (a flat-faced and a round profile, blended by `bulge`). It is built once per
  size/shape/seed (in a background isolate for large pieces), uploaded as two
  small textures, and cached (LRU, 32 entries, 4 MB).
- **Body:** a fragment shader computes frost, grain, reflections and the lower
  light exit per pixel. Changing color, light, frost or grain only updates
  uniforms; nothing is re-rasterized.
- **Ground:** cast shadow, contact shadow and colored light pool use blurred
  paths and always fall downward.
- **Fallback:** a gradient body is drawn for the first frame while geometry is
  prepared, and on any platform where the shader cannot load.

The glass does not blur or sample what is behind it; it is an opaque material.
Check text contrast if you use your own colors.

## Platform status

Checked visually on the Android emulator (Impeller, OpenGL ES), the iOS
simulator and web (CanvasKit); macOS builds and runs with the shader. Not yet
measured on physical low-end devices.

## License

Apache 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE). Based on Sea Glass for
Compose by Matt McKenna, also Apache 2.0.
