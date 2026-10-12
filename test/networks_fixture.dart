import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:yukari/models/network.dart';
import 'package:yukari/signals/networks.dart' as saved;

/// Seeds the saved networks `n1` ("alpha") and `n2` ("beta").
Future<void> seedNetworks() async {
  SharedPreferences.setMockInitialValues({
    'networks': jsonEncode({
      'n1': (Network()..networkName = 'alpha').toJson(),
      'n2': (Network()..networkName = 'beta').toJson(),
    }),
  });
  await saved.init();
}

/// The network `id` as persisted in shared preferences.
Future<Network> persisted(String id) async {
  final prefs = await SharedPreferences.getInstance();
  final json = jsonDecode(prefs.getString('networks')!) as Map<String, dynamic>;
  return Network.fromJson(json[id] as Map<String, dynamic>);
}
