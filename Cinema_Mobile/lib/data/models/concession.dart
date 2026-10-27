import 'json_readers.dart';

// A snack or drink sold with tickets, from the cinema's menu.
class ConcessionItem {
  const ConcessionItem({
    required this.id,
    required this.name,
    required this.price,
    this.description = '',
    this.imageUrl = '',
    this.active = true,
    this.sortOrder = 0,
  });

  factory ConcessionItem.fromJson(Map<String, Object?> json) => ConcessionItem(
    id: readInt(json['id']),
    name: readString(json['name']),
    price: readDouble(json['price']),
    description: readString(json['description']),
    imageUrl: readString(json['imageUrl']),
    active: json['active'] != false,
    sortOrder: readOptionalInt(json['sortOrder']) ?? 0,
  );

  final int id;
  final String name;
  final double price;
  final String description;
  final String imageUrl;

  // Stopped items are hidden from customers; old orders keep them.
  final bool active;
  final int sortOrder;
}

// Snacks bought with a booking, priced when it was made.
class BookingConcession {
  const BookingConcession({
    required this.itemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  factory BookingConcession.fromJson(Map<String, Object?> json) =>
      BookingConcession(
        itemId: readInt(json['itemId']),
        name: readString(json['name']),
        unitPrice: readDouble(json['unitPrice']),
        quantity: readOptionalInt(json['quantity']) ?? 1,
      );

  final int itemId;
  final String name;
  final double unitPrice;
  final int quantity;

  double get amount => unitPrice * quantity;

  String get label => '$quantity × $name';
}

// The price of the picked snacks (item id → quantity).
double snacksTotal(List<ConcessionItem> items, Map<int, int> quantities) =>
    items.fold(
      0,
      (total, item) => total + item.price * (quantities[item.id] ?? 0),
    );
