final class EasyTierFfiException implements Exception {
  const EasyTierFfiException(this.operation, this.message, [this.code]);

  final String operation;
  final String message;
  final int? code;

  @override
  String toString() => code == null
      ? 'EasyTierFfiException($operation): $message'
      : 'EasyTierFfiException($operation, code: $code): $message';
}
