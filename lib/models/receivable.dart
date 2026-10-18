import 'map_utils.dart';

enum ReceivableStatus { pending, received, partial }

class Receivable {
  final String id;
  final String description;
  final double expectedAmount;
  final double? receivedAmount;
  final DateTime expectedDate;
  final ReceivableStatus status;
  final bool isRecurring;

  const Receivable({
    required this.id,
    required this.description,
    required this.expectedAmount,
    this.receivedAmount,
    required this.expectedDate,
    this.status = ReceivableStatus.pending,
    this.isRecurring = false,
  });

  double get amountToReceive => expectedAmount - (receivedAmount ?? 0);

  Map<String, dynamic> toMap() => {
    'id': id,
    'description': description,
    'expected_amount': expectedAmount,
    'received_amount': receivedAmount,
    'expected_date': expectedDate.toIso8601String(),
    'status': status.name,
    'is_recurring': isRecurring ? 1 : 0,
  };

  factory Receivable.fromMap(Map<String, dynamic> map) => Receivable(
    id: map['id'] as String,
    description: map['description'] as String,
    expectedAmount: asDouble(map['expected_amount']),
    receivedAmount: asDoubleOrNull(map['received_amount']),
    expectedDate: DateTime.parse(map['expected_date'] as String),
    status: enumByName(ReceivableStatus.values, map['status'], ReceivableStatus.pending),
    isRecurring: asBool(map['is_recurring']),
  );
}
