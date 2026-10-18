import 'package:flutter/material.dart' show DateTimeRange;

class PaymentCard {
  final String id;
  final String name;
  final String? lastFour;
  final int closingDay;
  final int dueDay;
  final String color;

  const PaymentCard({
    required this.id,
    required this.name,
    this.lastFour,
    required this.closingDay,
    required this.dueDay,
    this.color = '#7C3AED',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'last_four': lastFour,
    'closing_day': closingDay,
    'due_day': dueDay,
    'color': color,
  };

  factory PaymentCard.fromMap(Map<String, dynamic> map) => PaymentCard(
    id: map['id'] as String,
    name: map['name'] as String,
    lastFour: map['last_four'] as String?,
    closingDay: map['closing_day'] as int,
    dueDay: map['due_day'] as int,
    color: map['color'] as String? ?? '#7C3AED',
  );

  PaymentCard copyWith({
    String? name,
    String? lastFour,
    int? closingDay,
    int? dueDay,
    String? color,
  }) => PaymentCard(
    id: id,
    name: name ?? this.name,
    lastFour: lastFour ?? this.lastFour,
    closingDay: closingDay ?? this.closingDay,
    dueDay: dueDay ?? this.dueDay,
    color: color ?? this.color,
  );

  /// The current billing cycle: from closing_day last month to closing_day this month
  DateTimeRange get currentCycle {
    final now = DateTime.now();
    DateTime start;
    DateTime end;
    if (now.day > closingDay) {
      start = DateTime(now.year, now.month, closingDay + 1);
      end   = DateTime(now.year, now.month + 1, closingDay);
    } else {
      start = DateTime(now.year, now.month - 1, closingDay + 1);
      end   = DateTime(now.year, now.month, closingDay);
    }
    return DateTimeRange(start: start, end: end);
  }

  /// Next due date
  DateTime get nextDueDate {
    final now = DateTime.now();
    final candidate = DateTime(now.year, now.month, dueDay);
    if (candidate.isAfter(now)) return candidate;
    return DateTime(now.year, now.month + 1, dueDay);
  }

  int get daysUntilDue => nextDueDate.difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
}
