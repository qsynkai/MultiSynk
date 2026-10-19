import 'map_utils.dart';
import 'transaction.dart' show PaymentMethod;

class FixedExpense {
  final String id;
  final String description;
  final double amount;
  final String category;
  final String scope; // 'studio' | 'personal'
  final bool isActive;
  final int dueDay;
  final PaymentMethod? paymentMethod;
  final String? cardId;

  const FixedExpense({
    required this.id,
    required this.description,
    required this.amount,
    this.category = '',
    required this.scope,
    this.isActive = true,
    this.dueDay = 10,
    this.paymentMethod,
    this.cardId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'description': description,
    'amount': amount,
    'category': category,
    'scope': scope,
    'is_active': isActive ? 1 : 0,
    'due_day': dueDay,
    'payment_method': paymentMethod?.name,
    'card_id': cardId,
  };

  factory FixedExpense.fromMap(Map<String, dynamic> map) => FixedExpense(
    id: map['id'] as String,
    description: map['description'] as String,
    amount: asDouble(map['amount']),
    category: map['category'] as String? ?? '',
    scope: map['scope'] as String? ?? 'personal',
    isActive: asBool(map['is_active'], true),
    dueDay: asInt(map['due_day'], 10),
    paymentMethod: enumByNameOrNull(PaymentMethod.values, map['payment_method']),
    cardId: map['card_id'] as String?,
  );

  FixedExpense copyWith({bool? isActive}) => FixedExpense(
    id: id,
    description: description,
    amount: amount,
    category: category,
    scope: scope,
    dueDay: dueDay,
    isActive: isActive ?? this.isActive,
    paymentMethod: paymentMethod,
    cardId: cardId,
  );
}
