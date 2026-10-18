import 'map_utils.dart';
import 'transaction.dart' show PaymentMethod;

class StudioEntry {
  final String id;
  final double amount;
  final String type; // 'revenue' | 'expense'
  final String description;
  final String? category;
  final DateTime date;
  final String? notes;
  final PaymentMethod? paymentMethod;
  final String? cardId;
  final int installments;
  final int installmentNumber;
  final String? installmentGroupId;

  const StudioEntry({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    this.category,
    required this.date,
    this.notes,
    this.paymentMethod,
    this.cardId,
    this.installments = 1,
    this.installmentNumber = 1,
    this.installmentGroupId,
  });

  bool get isRevenue => type == 'revenue';
  bool get isExpense => type == 'expense';
  bool get isInstallment => installments > 1;

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'type': type,
    'description': description,
    'category': category,
    'date': date.toIso8601String(),
    'notes': notes,
    'payment_method': paymentMethod?.name,
    'card_id': cardId,
    'installments': installments,
    'installment_number': installmentNumber,
    'installment_group_id': installmentGroupId,
  };

  factory StudioEntry.fromMap(Map<String, dynamic> map) => StudioEntry(
    id: map['id'] as String,
    amount: asDouble(map['amount']),
    type: map['type'] as String,
    description: map['description'] as String,
    category: map['category'] as String?,
    date: DateTime.parse(map['date'] as String),
    notes: map['notes'] as String?,
    paymentMethod: enumByNameOrNull(PaymentMethod.values, map['payment_method']),
    cardId: map['card_id'] as String?,
    installments: asInt(map['installments'], 1),
    installmentNumber: asInt(map['installment_number'], 1),
    installmentGroupId: map['installment_group_id'] as String?,
  );
}
