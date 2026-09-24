import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');
  final header = packageRoot.resolve('third_party/easytier/ffi.h');
  final generator = FfiGenerator(
    input: Input(
      entryPoints: [header],
      include: (candidate) => candidate == header,
    ),
    visitors: [
      Visitor(
        func: (node) => node.isIncluded = true,
        struct: (node) => node.isIncluded = true,
        macroConstant: (node) => node.isIncluded = true,
        typealias: (node) => node.isIncluded = TypealiasInclude.always,
      ),
    ],
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/bindings/generated/easytier.g.dart'),
      ),
      style: const NativeExternalBindings(
        assetId: 'package:yukari/bindings/generated/easytier.g.dart',
      ),
      commentType: const CommentType(CommentStyle.any, CommentLength.full),
    ),
  );
  await generator.generate();
}
