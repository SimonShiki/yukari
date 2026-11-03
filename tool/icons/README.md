# Launcher icons

Generated icons for different platforms. The generator config lives in
[`launcher_icons.yaml`](../../launcher_icons.yaml).

## Regenerate

```sh
cd tool/icons
dart pub get
dart run launcher_icons:launcher_icons -d "$PWD/../.." -c "$PWD/../.."
dart run render_svg.dart
```

`-d` and `-c` must be the absolute project root, or the Windows assets are
written to the wrong place.

`dart run render_svg.dart --check` verifies the rasters without rewriting them.

`render_svg.dart` needs `rsvg-convert` (librsvg) to draw the PNGs. The tray
icons are trimmed and centred with `magick` (ImageMagick), so regenerating them
needs `magick` too.

## Sources

| File | Use |
| --- | --- |
| `assets/yukari.svg` | Bare mark, white |
| `assets/yukari-on-light.svg` | Bare mark, brand colour, for light Windows surfaces |
| `assets/yukari-with-background.svg` | Pre-composed icon on the brand plate |

`render_svg.dart` rasterises these into `assets/generated/`, and writes the Linux
hicolor set straight from the SVG at each size. The generator's own SVG renderer
cannot draw the mark, so it is only ever given PNGs.

## Output

| Platform | Files |
| --- | --- |
| Android | `mipmap-*/ic_launcher.png`, `drawable-*/ic_launcher_{foreground,monochrome,round}.png`, `mipmap-anydpi-v26/ic_launcher{,_round}.xml`, `values/colors.xml` |
| Windows | `windows/runner/resources/app_icon.ico`, `windows/images/` |
| Linux | `assets/generated/yukari-with-background-1024.png`, `linux/share/`, `linux/runner/my_application.cc` patch, `linux/CMakeLists.txt` install block |
| Tray | `assets/generated/yukari-tray-{dark,light}.png`, the bare mark trimmed and centred at 32px |

Generated icons are committed: platform manifests reference them by path and
`flutter pub get` needs the declared Linux asset. Regeneration is deterministic.

Keep `android:icon` and `android:roundIcon` on the single line the generator
writes, or it re-inserts `roundIcon` and the manifest gets the attribute twice.
