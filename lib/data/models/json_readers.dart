// Small helpers for reading backend JSON (ASP.NET serializes camelCase).

Map<String, Object?> readMap(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  throw const FormatException('Expected a JSON object.');
}

List<Map<String, Object?>> readMapList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<Map>().map(Map<String, Object?>.from).toList();
}

int readInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('Expected a number but got $value.');
}

int? readOptionalInt(Object? value) {
  return value is num ? value.toInt() : null;
}

double readDouble(Object? value) {
  return value is num ? value.toDouble() : 0;
}

String readString(Object? value, {String fallback = ''}) {
  return value is String ? value : fallback;
}

String? readOptionalString(Object? value) {
  return value is String && value.trim().isNotEmpty ? value : null;
}

// The backend stores local time without an offset, so values without a
// suffix are already local. Values with an offset are converted to local.
DateTime? readDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}

DateTime readRequiredDateTime(Object? value) {
  final dateTime = readDateTime(value);
  if (dateTime == null) {
    throw FormatException('Expected a date but got $value.');
  }
  return dateTime;
}
