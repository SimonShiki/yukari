import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('launcher art', () {
    File asset(String name) => File('assets/$name');

    String markup(String name) =>
        asset(name).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

    for (final (:String file, :List<String> fills) in <({String file, List<String> fills})>[
      (file: 'yukari.svg', fills: ['#ffffff']),
      (file: 'yukari-on-light.svg', fills: ['#52298c']),
      (file: 'yukari-with-background.svg', fills: ['#52298c', '#f1e8fd']),
    ]) {
      test('${file.padRight(28)} carries its fills as presentation attributes', () {
        final svg = markup(file);
        final paths = RegExp('<path\\b[^>]*>').allMatches(svg).map((m) => m[0]!).toList();

        expect(paths, isNotEmpty, reason: '$file declares no paths');
        expect(svg, isNot(contains('<style')));
        expect(svg, isNot(contains('class="cls')));
        final used = <String>{};
        for (final path in paths) {
          final match = RegExp('fill="(#[0-9a-f]{6})"').firstMatch(path);
          expect(match, isNotNull, reason: 'unfilled path in $file:\n$path');
          used.add(match![1]!);
        }
        expect(used.difference(fills.toSet()), isEmpty, reason: 'unexpected fill in $file');
        expect(fills.toSet().difference(used), isEmpty, reason: 'missing fill in $file');
      });
    }

    test('the light-surface mark is the same geometry as the white mark', () {
      List<String> geometry(String file) =>
          RegExp('d="([^"]*)"').allMatches(markup(file)).map((m) => m[1]!).toList();

      final white = geometry('yukari.svg');
      expect(white, isNotEmpty);
      expect(geometry('yukari-on-light.svg'), white);
    });

    test('the Linux runtime icon exists and is declared', () {
      final icon = File('assets/generated/yukari-with-background-1024.png');
      expect(icon.existsSync(), isTrue, reason: 'run tool/icons/render_svg.dart');
      expect(icon.readAsBytesSync().sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('assets/generated/yukari-with-background-1024.png'),
      );
    });

    test('the Linux hicolor set has every size the SVG is rasterised to', () {
      // The generator would downscale one master PNG instead, which fades the
      // mark at small sizes. These must come from render_svg.dart.
      for (final size in [16, 22, 24, 32, 48, 64, 128, 256, 512]) {
        final icon = File('linux/share/icons/hicolor/${size}x$size/apps/yukari.png');
        expect(icon.existsSync(), isTrue, reason: 'run tool/icons/render_svg.dart');
        final bytes = icon.readAsBytesSync();
        expect((bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19], size);
        expect((bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23], size);
      }
    });

    test('the icon config feeds the generator rasterised PNGs', () {
      final sources = RegExp(
        r'^\s+(?:image_path\w*|adaptive_icon_(?:foreground|monochrome|round)):\s+"([^"]+)"',
        multiLine: true,
      ).allMatches(File('launcher_icons.yaml').readAsStringSync()).map((m) => m[1]!).toList();

      expect(sources, isNotEmpty);
      for (final source in sources) {
        expect(source, endsWith('.png'));
        expect(File(source).existsSync(), isTrue, reason: '$source does not exist');
      }
    });
  });
}
