import 'map_utils.dart';

class FixedExpensePayment {
  final String id;
  final String fixedExpenseId;
  final int year;
  final int month;
  final DateTime paidAt;

  const FixedExpensePayment({
    required this.id,
    required this.fixedExpenseId,
    required this.year,
    required this.month,
    required this.paidAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'fixed_expense_id': fixedExpenseId,
    'year': year,
    'month': month,
    'paid_at': paidAt.toIso8601String(),
  };

  factory FixedExpensePayment.fromMap(Map<String, dynamic> map) =>
      FixedExpensePayment(
        id: map['id'] as String,
        fixedExpenseId: map['fixed_expense_id'] as String,
        year: asInt(map['year']),
        month: asInt(map['month']),
        paidAt: DateTime.parse(map['paid_at'] as String),
      );
}
