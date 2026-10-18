// Tolerant readers for rows coming from SQLite or from the cloud (JSON): numbers may arrive as int
// where a double is expected (100 instead of 100.0) and flags as bool, int or string.

double asDouble(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : (double.tryParse('$v') ?? fallback);

double? asDoubleOrNull(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

int asInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : (int.tryParse('$v') ?? fallback);

int? asIntOrNull(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));

bool asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return fallback;
}

T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

T? enumByNameOrNull<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
