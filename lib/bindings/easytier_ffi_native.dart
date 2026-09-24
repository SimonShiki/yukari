import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:yukari/bindings/easytier_ffi_exception.dart';

import '../models/models.dart';
import '../utils/easytier_config_serializer.dart';
import 'generated/easytier.g.dart' as native;

EasyTierFfiException takeError(String operation, int code) {
  return using((arena) {
    final output = arena<Pointer<Char>>();
    native.get_error_msg(output);
    final pointer = output.value;
    final message = pointer == nullptr
        ? 'EasyTier did not return an error message'
        : pointer.cast<Utf8>().toDartString();
    if (pointer != nullptr) {
      native.free_string(pointer);
    }
    return EasyTierFfiException(operation, message, code);
  });
}

void parseConfig(String config) {
  final result = using((arena) {
    final pointer = config.toNativeUtf8(allocator: arena);
    return native.parse_config(pointer.cast());
  });
  if (result != 0) {
    throw takeError('parse_config', result);
  }
}

Future<void> runNetworkInstance(Network network) {
  // Runtime naming lets collect/stop address this network without a persisted ID.
  final tomlString =
      'instance_name = ${jsonEncode(network.networkName)}\n'
      '${network.toEasyTierToml()}';
  return Isolate.run(() {
    return using((arena) {
      final configuration = tomlString.toNativeUtf8(allocator: arena);
      final result = native.run_network_instance(configuration.cast());
      if (result != 0) {
        throw takeError('run_network_instance', result);
      }
    });
  });
}

Future<void> deleteNetworkInstances(List<String> names) {
  if (names.isEmpty) {
    return Future.value();
  }
  return Isolate.run(() {
    final result = using((arena) {
      final pointers = arena<Pointer<Char>>(names.length);
      for (var index = 0; index < names.length; index++) {
        pointers[index] = names[index].toNativeUtf8(allocator: arena).cast();
      }
      return native.delete_network_instance(pointers, names.length);
    });
    if (result != 0) {
      throw takeError('delete_network_instance', result);
    }
  });
}

Map<String, String> _readPairs(
  int Function(Pointer<native.KeyValuePair>, int) operation,
  String operationName,
) {
  const maxCapacity = 65536;
  var capacity = 16;
  while (capacity <= maxCapacity) {
    final pairs = calloc<native.KeyValuePair>(capacity);
    try {
      final count = operation(pairs, capacity);
      if (count < 0) {
        throw takeError(operationName, count);
      }
      final written = count < capacity ? count : capacity;
      final record = <String, String>{};
      for (var index = 0; index < written; index++) {
        final keyPointer = pairs[index].key;
        final valuePointer = pairs[index].value;
        final key = keyPointer.cast<Utf8>().toDartString();
        final value = valuePointer.cast<Utf8>().toDartString();
        record[key] = value;
      }
      if (count <= capacity) {
        return record;
      }
      capacity = count > capacity * 2 ? count : capacity * 2;
    } finally {
      calloc.free(pairs);
    }
  }
  throw StateError(
    'The number of pairs exceeded the maximum capacity of $maxCapacity',
  );
}

Map<String, String> getInstanceNameIdMap() {
  return _readPairs(native.list_instance, 'list_instance');
}

/// Collects running network instance's information from the given networks.
Future<Map<String, Instance>> collectNetworkInfos(Map<String, Network> networks) async {
  Map<String, String> infos = await Isolate.run(() {
    return _readPairs(native.collect_network_infos, 'collect_network_infos');
  });
  return hydrateNetworkInfos(
    networks,
    infos,
  );
}

Map<String, Instance> hydrateNetworkInfos(
  Map<String, Network> networks,
  Map<String, String> infos,
) => {
  for (final entry in networks.entries)
    if (infos[entry.value.networkName] case final info?)
      entry.key: Instance.fromJsonAndNetwork(
        jsonDecode(info) as Map<String, Object?>,
        entry.value,
      ),
};

/// Set TUN file descriptor for an Android network instance.
/// This must be called after starting the instance on Android.
void setTunFd(String instanceName, int fd) {
  using((arena) {
    final namePointer = instanceName.toNativeUtf8(allocator: arena);
    final result = native.set_tun_fd(namePointer.cast(), fd);
    if (result != 0) {
      throw takeError('set_tun_fd', result);
    }
  });
}
