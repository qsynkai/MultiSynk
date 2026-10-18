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
    id: map['id'],
    amount: (map['amount'] as num).toDouble(),
    type: map['type'],
    description: map['description'],
    category: map['category'],
    date: DateTime.parse(map['date']),
    notes: map['notes'],
    paymentMethod: map['payment_method'] != null
        ? PaymentMethod.values.byName(map['payment_method'])
        : null,
    cardId: map['card_id'],
    installments: map['installments'] as int? ?? 1,
    installmentNumber: map['installment_number'] as int? ?? 1,
    installmentGroupId: map['installment_group_id'],
  );
}
