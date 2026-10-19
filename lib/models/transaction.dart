import 'map_utils.dart';

enum TransactionType { income, expense }

enum PaymentMethod { cash, pix, debit, credit }

class Transaction {
  final String id;
  final String description;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String? category;
  final String? vehicleId;
  final PaymentMethod? paymentMethod;
  final String? cardId;
  final int installments;
  final int installmentNumber;
  final String? installmentGroupId;
  final String? studioEntryId;

  const Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
    this.category,
    this.vehicleId,
    this.paymentMethod,
    this.cardId,
    this.installments = 1,
    this.installmentNumber = 1,
    this.installmentGroupId,
    this.studioEntryId,
  });

  bool get isInstallment => installments > 1;

  Map<String, dynamic> toMap() => {
    'id': id,
    'description': description,
    'amount': amount,
    'type': type.name,
    'date': date.toIso8601String(),
    'category': category,
    'vehicle_id': vehicleId,
    'payment_method': paymentMethod?.name,
    'card_id': cardId,
    'installments': installments,
    'installment_number': installmentNumber,
    'installment_group_id': installmentGroupId,
    'studio_entry_id': studioEntryId,
  };

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
    id: map['id'] as String,
    description: map['description'] as String,
    amount: asDouble(map['amount']),
    type: enumByName(TransactionType.values, map['type'], TransactionType.expense),
    date: DateTime.parse(map['date'] as String),
    category: map['category'] as String?,
    vehicleId: map['vehicle_id'] as String?,
    paymentMethod: enumByNameOrNull(PaymentMethod.values, map['payment_method']),
    cardId: map['card_id'] as String?,
    installments: asInt(map['installments'], 1),
    installmentNumber: asInt(map['installment_number'], 1),
    installmentGroupId: map['installment_group_id'] as String?,
    studioEntryId: map['studio_entry_id'] as String?,
  );

  Transaction copyWith({
    String? description,
    double? amount,
    TransactionType? type,
    DateTime? date,
    String? category,
    String? vehicleId,
    PaymentMethod? paymentMethod,
    String? cardId,
    int? installments,
    int? installmentNumber,
    String? installmentGroupId,
    String? studioEntryId,
  }) => Transaction(
    id: id,
    description: description ?? this.description,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    date: date ?? this.date,
    category: category ?? this.category,
    vehicleId: vehicleId ?? this.vehicleId,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    cardId: cardId ?? this.cardId,
    installments: installments ?? this.installments,
    installmentNumber: installmentNumber ?? this.installmentNumber,
    installmentGroupId: installmentGroupId ?? this.installmentGroupId,
    studioEntryId: studioEntryId ?? this.studioEntryId,
  );
}
