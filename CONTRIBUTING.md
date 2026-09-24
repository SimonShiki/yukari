# Development

## Pre-requisites
tbd

## Generated code

Generate Isar schemas, JSON serializers, and FFI bindings after changing
database models or bumping easytier versions:

```shell
dart run build_runner build
dart run tool/ffigen.dart
```

During database development, keep generated output updated continuously:

```shell
dart run build_runner watch
```

# Contributing
