import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:signals/signals.dart' as sig;
import 'package:yukari/models/network.dart';
import 'package:yukari/signals/networks.dart';
import 'package:yukari/utils/json_store.dart';

/// Directory [init] is pointed at for the current test.
late Directory dir;

File indexFile() => File('${dir.path}/index.json');

File networkFile(String name) => File('${dir.path}/$name.json');

Network savedNetwork(String name, {String? hostname}) =>
    Network(name)
      ..hostname = hostname;

/// Writes the layout [init] expects: an index plus one file per network.
void seed(Map<String, Network> saved, {List<String>? order}) {
  indexFile().writeAsStringSync(jsonEncode(order ?? saved.keys.toList()));
  saved.forEach(
    (name, network) =>
        networkFile(name).writeAsStringSync(jsonEncode(network.toJson())),
  );
}

List<String> diskIndex() =>
    (jsonDecode(indexFile().readAsStringSync()) as List<dynamic>)
        .cast<String>()
        .toList();

Network diskNetwork(String name) => Network.fromJson(
  jsonDecode(networkFile(name).readAsStringSync()) as Map<String, dynamic>,
);

/// Pumps the event loop until [condition] holds. Effects persist in the
/// background, so every disk assertion waits instead of racing the write.
Future<void> waitFor(bool Function() condition, String description) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (true) {
    try {
      if (condition()) return;
    } catch (_) {
      // Missing or half-written file: poll again.
    }
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $description');
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

Future<void> waitForIndex(List<String> names) => waitFor(
  () => jsonEncode(diskIndex()) == jsonEncode(names),
  'index.json to become $names',
);

Future<void> waitForNetwork(String name, bool Function(Network) matches) =>
    waitFor(
      () => networkFile(name).existsSync() && matches(diskNetwork(name)),
      '$name.json to match',
    );

Future<void> waitForRemoved(File file) =>
    waitFor(() => !file.existsSync(), '${file.path} to be deleted');

void main() {
  setUp(() {
    dir = Directory.systemTemp.createTempSync('yukari_networks_');
  });

  tearDown(() async {
    await dispose();
    // Effects write in the background; let pending writes land before the
    // directory disappears, otherwise the failed save fails the next test.
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('init starts an empty collection in a fresh directory', () async {
    expect(await init(dir.path), isFalse);
    expect(index.value, isEmpty);
    expect(networks.value, isEmpty);
    await waitForIndex([]);
  });

  test('init loads the saved order and every network', () async {
    seed({
      'alpha': savedNetwork('alpha', hostname: 'relay'),
      'beta': savedNetwork('beta'),
    }, order: ['beta', 'alpha']);

    expect(await init(dir.path), isFalse);

    expect(index.value, ['beta', 'alpha']);
    expect(networks.value.keys.toList(), ['beta', 'alpha']);
    expect(networks.value['alpha']!.hostname, 'relay');
  });

  test('init reports and rewrites an index that is not valid JSON', () async {
    indexFile().writeAsStringSync('{ not json');

    expect(await init(dir.path), isTrue);
    expect(index.value, isEmpty);
    await waitForIndex([]);
  });

  test('init drops repeated index entries', () async {
    seed({'alpha': savedNetwork('alpha')}, order: ['alpha', 'alpha']);

    expect(await init(dir.path), isTrue);
    expect(index.value, ['alpha']);
    await waitForIndex(['alpha']);
  });

  test('init drops index entries whose file is missing', () async {
    seed({'alpha': savedNetwork('alpha')}, order: ['alpha', 'ghost']);

    expect(await init(dir.path), isTrue);
    expect(index.value, ['alpha']);
    expect(networks.value.containsKey('ghost'), isFalse);
    await waitForIndex(['alpha']);
  });

  test('init drops index entries that are not names', () async {
    indexFile().writeAsStringSync('[1]');

    expect(await init(dir.path), isTrue);
    expect(index.value, isEmpty);
    await waitForIndex([]);
  });

  test('init throws when a saved network cannot be decoded', () async {
    seed({'alpha': savedNetwork('alpha')});
    networkFile('alpha').writeAsStringSync('{"networkName": 42}');

    await expectLater(
      init(dir.path),
      throwsA(
        isA<StorageException>().having(
          (e) => e.message,
          'message',
          contains('alpha'),
        ),
      ),
    );
  });

  test('addNetwork appends in order and persists the files', () async {
    await init(dir.path);

    addNetwork('alpha', savedNetwork('alpha', hostname: 'relay'));
    addNetwork('beta', savedNetwork('beta'));

    expect(index.value, ['alpha', 'beta']);
    expect(networks.value['alpha']!.hostname, 'relay');
    await waitForIndex(['alpha', 'beta']);
    await waitForNetwork('alpha', (n) => n.hostname == 'relay');
    await waitForNetwork('beta', (n) => n.networkName == 'beta');
  });

  test('addNetwork rejects a duplicate name', () async {
    await init(dir.path);
    addNetwork('alpha', savedNetwork('alpha'));

    expect(() => addNetwork('alpha', savedNetwork('alpha')), throwsStateError);
    expect(index.value, ['alpha']);
    expect(networks.value.length, 1);
  });

  test('reorderIndex moves an entry and persists the order', () async {
    await init(dir.path);
    for (final name in ['alpha', 'beta', 'gamma']) {
      addNetwork(name, savedNetwork(name));
    }

    reorderIndex(0, 2);

    expect(index.value, ['beta', 'gamma', 'alpha']);
    await waitForIndex(['beta', 'gamma', 'alpha']);
  });

  test('reorderIndex rejects out-of-range positions', () async {
    await init(dir.path);
    addNetwork('alpha', savedNetwork('alpha'));

    expect(() => reorderIndex(1, 0), throwsRangeError);
    expect(() => reorderIndex(0, 1), throwsRangeError);
    expect(() => reorderIndex(-1, 0), throwsRangeError);
    expect(index.value, ['alpha']);
  });

  test('updateNetwork replaces the instance subscribers and disk see', () async {
    await init(dir.path);
    addNetwork('alpha', savedNetwork('alpha', hostname: 'old'));
    await waitForNetwork('alpha', (n) => n.hostname == 'old');

    final before = networks.value['alpha']!;
    Network? latest;
    addTearDown(
      sig.effect(() {
        latest = networks.value['alpha'];
      }),
    );

    updateNetwork('alpha', updater: (n) => before.hostname = 'new');
    await pumpEventQueue();

    expect(networks.value['alpha'], isNot(same(before)));
    expect(latest!.hostname, 'new');
    await waitForNetwork('alpha', (n) => n.hostname == 'new');
  });

  test('updateNetwork rejects an unknown name', () async {
    await init(dir.path);

    expect(() => updateNetwork('ghost', updater: (n) {}), throwsStateError);
  });

  test('renameNetwork keeps the position and moves the file', () async {
    await init(dir.path);
    for (final name in ['alpha', 'beta', 'gamma']) {
      addNetwork(name, savedNetwork(name));
    }
    await waitForIndex(['alpha', 'beta', 'gamma']);

    renameNetwork('beta', 'delta');

    expect(index.value, ['alpha', 'delta', 'gamma']);
    expect(networks.value.containsKey('beta'), isFalse);
    expect(networks.value['delta']!.networkName, 'delta');
    await waitForIndex(['alpha', 'delta', 'gamma']);
    await waitForNetwork('delta', (n) => n.networkName == 'delta');
    await waitForRemoved(networkFile('beta'));
  });

  test('renameNetwork rejects a missing source and a taken target', () async {
    await init(dir.path);
    addNetwork('alpha', savedNetwork('alpha'));
    addNetwork('beta', savedNetwork('beta'));

    expect(() => renameNetwork('ghost', 'delta'), throwsStateError);
    expect(() => renameNetwork('alpha', 'beta'), throwsStateError);
    expect(index.value, ['alpha', 'beta']);
  });

  test('removeNetwork drops it and deletes the file', () async {
    await init(dir.path);
    addNetwork('alpha', savedNetwork('alpha'));
    addNetwork('beta', savedNetwork('beta'));
    await waitForIndex(['alpha', 'beta']);
    await waitForNetwork('beta', (n) => n.networkName == 'beta');

    removeNetwork('alpha');

    expect(index.value, ['beta']);
    expect(networks.value.keys.toList(), ['beta']);
    await waitForIndex(['beta']);
    await waitForRemoved(networkFile('alpha'));
  });

  test('reloading after dispose restores what was persisted', () async {
    await init(dir.path);
    addNetwork('alpha', savedNetwork('alpha', hostname: 'relay'));
    await waitForIndex(['alpha']);
    await waitForNetwork('alpha', (n) => n.hostname == 'relay');

    await dispose();
    expect(index.value, isEmpty);
    expect(networks.value, isEmpty);

    expect(await init(dir.path), isFalse);
    expect(index.value, ['alpha']);
    expect(networks.value['alpha']!.hostname, 'relay');
  });

  test('index and networks notify subscribers on add and remove', () async {
    await init(dir.path);

    final lengths = <int>[];
    final counts = <int>[];
    addTearDown(
      sig.effect(() {
        lengths.add(index.value.length);
      }),
    );
    addTearDown(
      sig.effect(() {
        counts.add(networks.value.length);
      }),
    );
    expect(lengths, [0]);
    expect(counts, [0]);

    addNetwork('alpha', savedNetwork('alpha'));
    await pumpEventQueue();
    expect(lengths, [0, 1]);
    expect(counts, [0, 1]);

    removeNetwork('alpha');
    await pumpEventQueue();
    expect(lengths, [0, 1, 0]);
    expect(counts, [0, 1, 0]);
  });
}
