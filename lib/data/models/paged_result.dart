import 'json_readers.dart';

class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.pageNumber,
    required this.totalPages,
    required this.totalCount,
  });

  factory PagedResult.fromJson(
    Object? json,
    T Function(Map<String, Object?> item) fromItem,
  ) {
    final map = readMap(json);
    return PagedResult(
      items: readMapList(map['items']).map(fromItem).toList(),
      pageNumber: readOptionalInt(map['pageNumber']) ?? 1,
      totalPages: readOptionalInt(map['totalPages']) ?? 1,
      totalCount: readOptionalInt(map['totalCount']) ?? 0,
    );
  }

  final List<T> items;
  final int pageNumber;
  final int totalPages;
  final int totalCount;
}
