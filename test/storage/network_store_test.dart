import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yukari_core/models/network.dart';
import 'package:yukari_core/storage/network_store.dart';

import '../networks_fixture.dart';

void main() {
  Network named(String name) => Network()..networkName = name;

  test('saves and loads networks in order', () async {
    final store = temporaryStore();
    await store.save({'b': named('beta'), 'a': named('alpha')});

    final loaded = await NetworkStore(store.file, readOnly: true).load();
    expect(loaded.keys, ['b', 'a']);
    expect(loaded['a']!.networkName, 'alpha');
  });

  test('a missing file holds no networks', () async {
    expect(await temporaryStore().load(), isEmpty);
  });

  test('a read-only store refuses to write', () async {
    final store = NetworkStore(temporaryStore().file, readOnly: true);
    expect(() => store.save({}), throwsStateError);
  });

  group('secrets stay private', () {
    int mode(File file) => file.statSync().mode & 0x1FF;

    test('a save is readable by its owner alone', () async {
      final store = temporaryStore();
      await store.save({'a': named('alpha')..networkSecret = 'secret'});

      expect(mode(store.file), 0x180 /* 0600 */);
      expect(
        store.file.parent.listSync().map((entry) => entry.path),
        [store.file.path],
        reason: 'no temporary file is left behind',
      );
    });

    test('a save replaces a symlink rather than writing through it', () async {
      final store = temporaryStore();
      final victim = File('${store.file.parent.path}/victim')
        ..writeAsStringSync('keep');
      Link(store.file.path).createSync(victim.path);

      await store.save({'a': named('alpha')});

      expect(victim.readAsStringSync(), 'keep');
      expect(FileSystemEntity.isLinkSync(store.file.path), isFalse);
    });

    test('loading tightens a file an older version left readable', () async {
      final store = temporaryStore();
      await store.save({'a': named('alpha')});
      await Process.run('chmod', ['644', store.file.path]);

      await store.load();

      expect(mode(store.file), 0x180 /* 0600 */);
    });

    test('the read-only service leaves the mode alone', () async {
      final store = temporaryStore();
      await store.save({'a': named('alpha')});
      await Process.run('chmod', ['644', store.file.path]);

      await NetworkStore(store.file, readOnly: true).load();

      expect(mode(store.file), 0x1A4 /* 0644 */);
    });
  }, skip: Platform.isWindows ? 'Windows has no file modes' : false);
}
