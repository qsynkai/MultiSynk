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
  final String? linkedTransactionId;

  const Receivable({
    required this.id,
    required this.description,
    required this.expectedAmount,
    this.receivedAmount,
    required this.expectedDate,
    this.status = ReceivableStatus.pending,
    this.isRecurring = false,
    this.linkedTransactionId,
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
    'linked_transaction_id': linkedTransactionId,
  };

  factory Receivable.fromMap(Map<String, dynamic> map) => Receivable(
    id: map['id'] as String,
    description: map['description'] as String,
    expectedAmount: asDouble(map['expected_amount']),
    receivedAmount: asDoubleOrNull(map['received_amount']),
    expectedDate: DateTime.parse(map['expected_date'] as String),
    status: enumByName(ReceivableStatus.values, map['status'], ReceivableStatus.pending),
    isRecurring: asBool(map['is_recurring']),
    linkedTransactionId: map['linked_transaction_id'] as String?,
  );

  Receivable copyWith({
    ReceivableStatus? status,
    double? receivedAmount,
    String? linkedTransactionId,
    bool clearLinkedTransaction = false,
  }) => Receivable(
    id: id,
    description: description,
    expectedAmount: expectedAmount,
    receivedAmount: receivedAmount ?? this.receivedAmount,
    expectedDate: expectedDate,
    status: status ?? this.status,
    isRecurring: isRecurring,
    linkedTransactionId: clearLinkedTransaction ? null : (linkedTransactionId ?? this.linkedTransactionId),
  );
}
