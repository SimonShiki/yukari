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
}
