const _units = ['B', 'KB', 'MB', 'GB', 'TB'];

/// [bytes] in the largest unit that keeps it at least 1, such as `1.5 MB`.
String formatBytes(num bytes) {
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < _units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 || value >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${_units[unit]}';
}
