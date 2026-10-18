import 'package:flutter/material.dart' show DateTimeRange;
import '../logic/money.dart' show daysInMonth, dateOnly;
import 'map_utils.dart';

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
    closingDay: asInt(map['closing_day'], 1),
    dueDay: asInt(map['due_day'], 10),
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

  /// Closing date of [year]/[month], clamped to the month's length (day 31 → Feb 28/29).
  DateTime _closingIn(int year, int month) {
    final first = DateTime(year, month, 1);
    return DateTime(first.year, first.month, closingDay.clamp(1, daysInMonth(first.year, first.month)));
  }

  /// Current billing cycle: from the day after the previous closing up to and including
  /// the whole closing day. `end` is exclusive (00:00 of the day after closing), so
  /// purchases made at any time on the closing day belong to this cycle.
  DateTimeRange cycleAt(DateTime now) {
    final today = dateOnly(now);
    var closing = _closingIn(today.year, today.month);
    if (today.isAfter(closing)) closing = _closingIn(today.year, today.month + 1);
    final previousClosing = _closingIn(closing.year, closing.month - 1);
    return DateTimeRange(
      start: previousClosing.add(const Duration(days: 1)),
      end: closing.add(const Duration(days: 1)),
    );
  }

  DateTimeRange get currentCycle => cycleAt(DateTime.now());

  /// Next due date, counting today as due when today is the due day.
  DateTime nextDueDateAt(DateTime now) {
    final today = dateOnly(now);
    final thisMonth = DateTime(today.year, today.month, dueDay.clamp(1, daysInMonth(today.year, today.month)));
    if (!thisMonth.isBefore(today)) return thisMonth;
    final next = DateTime(today.year, today.month + 1, 1);
    return DateTime(next.year, next.month, dueDay.clamp(1, daysInMonth(next.year, next.month)));
  }

  DateTime get nextDueDate => nextDueDateAt(DateTime.now());

  int daysUntilDueAt(DateTime now) => nextDueDateAt(now).difference(dateOnly(now)).inDays;

  int get daysUntilDue => daysUntilDueAt(DateTime.now());
}
