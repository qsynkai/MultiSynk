import '../models/fixed_expense.dart';
import '../models/receivable.dart';
import '../models/transaction.dart';
import 'money.dart';

const merivaId = 'meriva-001';

/// Household expenses: everything except business vehicles (the Fiorino is tracked on its own screen).
bool isHouseholdExpense(Transaction t) =>
    t.type == TransactionType.expense && (t.vehicleId == null || t.vehicleId == merivaId);

String fixedExpenseTransactionId(String fixedId, DateTime month) => 'fe-$fixedId-${month.year}-${month.month}';

bool _inMonth(DateTime d, DateTime ref) => d.year == ref.year && d.month == ref.month;

class BudgetSnapshot {
  final double monthIncome;
  final double receivablesDue;
  final double monthExpenses;
  final double pendingFixed;
  final double weekSpent;
  final int weeksLeft;

  const BudgetSnapshot({
    required this.monthIncome,
    required this.receivablesDue,
    required this.monthExpenses,
    required this.pendingFixed,
    required this.weekSpent,
    required this.weeksLeft,
  });

  /// Money still free this month after everything already spent or committed.
  double get available => monthIncome + receivablesDue - monthExpenses - pendingFixed;

  /// What can still be spent this week: the month's remaining money as it stood at the start of
  /// the week, split evenly over the weeks left (including this one), minus this week's spending.
  double get weeklyBudget => roundCents((available + weekSpent) / weeksLeft - weekSpent);
}

/// Inclusive count of days from [now] to the end of its month, in started weeks (minimum 1).
int weeksLeftInMonth(DateTime now) {
  final daysLeft = daysInMonth(now.year, now.month) - now.day + 1;
  return ((daysLeft + 6) ~/ 7).clamp(1, 5);
}

BudgetSnapshot computeBudget({
  required DateTime now,
  required List<Transaction> transactions,
  required List<Receivable> receivables,
  required List<FixedExpense> personalFixed,
  Set<String> paidFixedExpenseIds = const {},
  double fiorinoMonthAvailable = 0,
  double studioMonthProlabore = 0,
}) {
  final today = dateOnly(now);
  final endOfToday = today.add(const Duration(days: 1));
  final monthStart = DateTime(now.year, now.month, 1);
  final nextMonthStart = DateTime(now.year, now.month + 1, 1);
  final weekStart = today.subtract(Duration(days: now.weekday - 1));
  final spendFrom = weekStart.isBefore(monthStart) ? monthStart : weekStart;

  double monthIncome = fiorinoMonthAvailable + studioMonthProlabore;
  double monthExpenses = 0;
  double weekSpent = 0;

  for (final t in transactions) {
    if (!_inMonth(t.date, now)) continue;
    if (t.type == TransactionType.income) {
      monthIncome += t.amount;
    } else if (isHouseholdExpense(t)) {
      // Future-dated expenses in this month (e.g. installments) are already committed money.
      monthExpenses += t.amount;
      if (!t.date.isBefore(spendFrom) && t.date.isBefore(endOfToday)) weekSpent += t.amount;
    }
  }

  // Only receivables due this month or earlier that haven't been received yet
  final receivablesDue = receivables
      .where((r) =>
          r.status != ReceivableStatus.received &&
          r.expectedDate.year == now.year &&
          r.expectedDate.month == now.month)
      .fold(0.0, (s, r) => s + r.amountToReceive);

  // pendingFixed: active personal fixed expenses NOT yet marked paid this month
  final pendingFixed = personalFixed
      .where((fe) => fe.isActive && !paidFixedExpenseIds.contains(fe.id))
      .fold(0.0, (s, fe) => s + fe.amount);

  return BudgetSnapshot(
    monthIncome: roundCents(monthIncome),
    receivablesDue: roundCents(receivablesDue),
    monthExpenses: roundCents(monthExpenses),
    pendingFixed: roundCents(pendingFixed),
    weekSpent: roundCents(weekSpent),
    weeksLeft: weeksLeftInMonth(now),
  );
}
