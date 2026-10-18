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
    quantity: map['quantity'] as int? ?? 1,
    estimatedPrice: map['estimated_price'] != null ? (map['estimated_price'] as num).toDouble() : null,
    category: ShoppingCategory.values.byName(map['category'] as String? ?? 'outro'),
    isPurchased: (map['is_purchased'] as int? ?? 0) == 1,
    aiPriority: map['ai_priority'] != null ? ShoppingPriority.values.byName(map['ai_priority'] as String) : null,
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
