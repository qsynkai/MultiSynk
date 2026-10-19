import 'map_utils.dart';

class CardBillPayment {
  final String id;
  final String cardId;
  final int year;
  final int month;
  final double? amount;
  final DateTime paidAt;

  const CardBillPayment({
    required this.id,
    required this.cardId,
    required this.year,
    required this.month,
    this.amount,
    required this.paidAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'card_id': cardId,
    'year': year,
    'month': month,
    'amount': amount,
    'paid_at': paidAt.toIso8601String(),
  };

  factory CardBillPayment.fromMap(Map<String, dynamic> map) => CardBillPayment(
    id: map['id'] as String,
    cardId: map['card_id'] as String,
    year: asInt(map['year']),
    month: asInt(map['month']),
    amount: asDoubleOrNull(map['amount']),
    paidAt: DateTime.parse(map['paid_at'] as String),
  );
}
