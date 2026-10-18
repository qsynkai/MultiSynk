import 'map_utils.dart';

enum ShoppingCategory { alimentacao, limpeza, higiene, eletronico, roupa, farmacia, outro }

enum ShoppingPriority { urgent, high, medium, low, none }

class ShoppingItem {
  final String id;
  final String description;
  final int quantity;
  final double? estimatedPrice;
  final ShoppingCategory category;
  final bool isPurchased;
  final ShoppingPriority? aiPriority;
  final String? aiReason;
  final DateTime createdAt;

  const ShoppingItem({
    required this.id,
    required this.description,
    this.quantity = 1,
    this.estimatedPrice,
    this.category = ShoppingCategory.outro,
    this.isPurchased = false,
    this.aiPriority,
    this.aiReason,
    required this.createdAt,
  });

  ShoppingPriority get effectivePriority => aiPriority ?? ShoppingPriority.none;

  Map<String, dynamic> toMap() => {
    'id': id,
    'description': description,
    'quantity': quantity,
    'estimated_price': estimatedPrice,
    'category': category.name,
    'is_purchased': isPurchased ? 1 : 0,
    'ai_priority': aiPriority?.name,
    'ai_reason': aiReason,
    'created_at': createdAt.toIso8601String(),
  };

  factory ShoppingItem.fromMap(Map<String, dynamic> map) => ShoppingItem(
    id: map['id'] as String,
    description: map['description'] as String,
    quantity: asInt(map['quantity'], 1),
    estimatedPrice: asDoubleOrNull(map['estimated_price']),
    category: enumByName(ShoppingCategory.values, map['category'], ShoppingCategory.outro),
    isPurchased: asBool(map['is_purchased']),
    aiPriority: enumByNameOrNull(ShoppingPriority.values, map['ai_priority']),
    aiReason: map['ai_reason'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  ShoppingItem copyWith({bool? isPurchased, ShoppingPriority? aiPriority, String? aiReason}) => ShoppingItem(
    id: id,
    description: description,
    quantity: quantity,
    estimatedPrice: estimatedPrice,
    category: category,
    isPurchased: isPurchased ?? this.isPurchased,
    aiPriority: aiPriority ?? this.aiPriority,
    aiReason: aiReason ?? this.aiReason,
    createdAt: createdAt,
  );
}
