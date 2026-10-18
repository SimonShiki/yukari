// Rasterises assets/*.svg into assets/generated/ with rsvg-convert; the tray
// icons are trimmed and centred with ImageMagick's magick.
//   dart run render_svg.dart            write
//   dart run render_svg.dart --check    verify only
import 'dart:io';

const List<({String source, String output})> masters = [
  (source: 'yukari.svg', output: 'yukari-1024.png'),
  (source: 'yukari-on-light.svg', output: 'yukari-on-light-1024.png'),
  (source: 'yukari-with-background.svg', output: 'yukari-with-background-1024.png'),
];

const List<int> hicolorSizes = [16, 22, 24, 32, 48, 64, 128, 256, 512];

/// The tray icons: the bare mark, trimmed of its transparent margin and
/// centred in a panel-sized square. White for dark panels, brand for light.
const List<({String source, String output})> trayMasters = [
  (source: 'yukari.svg', output: 'yukari-tray-dark.png'),
  (source: 'yukari-on-light.svg', output: 'yukari-tray-light.png'),
];

const int trayIconSize = 32;
const int trayGlyphSize = 26;

Future<void> main(List<String> args) async {
  final checkOnly = args.contains('--check');
  final assets = Directory('../../assets');
  final generated = Directory('${assets.path}/generated');
  final failures = <String>[];
  var written = 0;

  final jobs = <({String source, File output, int size})>[
    for (final master in masters)
      (
        source: '${assets.path}/${master.source}',
        output: File('${generated.path}/${master.output}'),
        size: 1024,
      ),
    for (final size in hicolorSizes)
      (
        source: '${assets.path}/yukari-with-background.svg',
        output: File('../../linux/share/icons/hicolor/${size}x$size/apps/yukari.png'),
        size: size,
      ),
  ];

  if (!checkOnly) generated.createSync(recursive: true);

  for (final job in jobs) {
    if (checkOnly) {
      if (!job.output.existsSync()) {
        failures.add('${job.output.path} is missing; run without --check');
      } else if (_pngSize(job.output) != (job.size, job.size)) {
        failures.add('${job.output.path} is not ${job.size}x${job.size}');
      }
      continue;
    }
    if (!File(job.source).existsSync()) {
      failures.add('missing source ${job.source}');
      continue;
    }
    job.output.parent.createSync(recursive: true);
    try {
      final result = await Process.run('rsvg-convert', [
        '-w', '${job.size}',
        '-h', '${job.size}',
        job.source,
        '-o', job.output.path,
      ]);
      if (result.exitCode != 0) {
        failures.add('rsvg-convert failed for ${job.output.path}: ${result.stderr}');
        continue;
      }
      final size = _pngSize(job.output);
      if (size != (job.size, job.size)) {
        failures.add('${job.output.path} rendered ${size?.$1}x${size?.$2}, expected ${job.size}');
        continue;
      }
      written++;
    } on ProcessException catch (error) {
      stderr.writeln('cannot run rsvg-convert (${error.message}). Install librsvg and retry.');
      exit(69);
    }
  }

  for (final master in trayMasters) {
    final output = File('${generated.path}/${master.output}');
    if (checkOnly) {
      if (!output.existsSync()) {
        failures.add('${output.path} is missing; run without --check');
      } else if (_pngSize(output) != (trayIconSize, trayIconSize)) {
        failures.add('${output.path} is not ${trayIconSize}x$trayIconSize');
      }
      continue;
    }
    try {
      if (!await _renderTrayIcon('${assets.path}/${master.source}', output)) {
        failures.add('cannot render ${output.path} from ${master.source}');
        continue;
      }
    } on ProcessException catch (error) {
      final install = error.executable == 'magick' ? 'ImageMagick' : 'librsvg';
      stderr.writeln('cannot run ${error.executable} (${error.message}). Install $install and retry.');
      exit(69);
    }
    written++;
  }

  if (failures.isNotEmpty) {
    for (final failure in failures) {
      stderr.writeln('  - $failure');
    }
    exit(1);
  }
  final count = jobs.length + trayMasters.length;
  stdout.writeln(checkOnly ? 'verified $count rendered assets' : 'wrote $written rendered assets');
}

/// Renders the bare mark, trims its transparent margin and centres it in the
/// tray's square, so the glyph fills a panel-sized slot instead of the 72% a
/// straight downscale of the padding-heavy master would.
Future<bool> _renderTrayIcon(String source, File output) async {
  final master = File('${output.parent.path}/.${output.uri.pathSegments.last}.master.png');
  try {
    final rendered = await Process.run('rsvg-convert', ['-w', '128', '-h', '128', source, '-o', master.path]);
    if (rendered.exitCode != 0) return false;
    final trimmed = await Process.run('magick', [
      master.path,
      '-trim', '+repage',
      '-resize', '${trayGlyphSize}x$trayGlyphSize',
      '-background', 'none',
      '-gravity', 'center',
      '-extent', '${trayIconSize}x$trayIconSize',
      output.path,
    ]);
    return trimmed.exitCode == 0 && _pngSize(output) == (trayIconSize, trayIconSize);
  } finally {
    if (master.existsSync()) master.deleteSync();
  }
}

(int, int)? _pngSize(File file) {
  final bytes = file.readAsBytesSync();
  if (bytes.length < 24 || bytes[1] != 0x50 || bytes[2] != 0x4e || bytes[3] != 0x47) return null;
  int read32(int at) =>
      (bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3];
  return (read32(16), read32(20));
}
