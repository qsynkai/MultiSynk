import 'package:flutter_test/flutter_test.dart';
import 'package:multisynk/logic/budget.dart';
import 'package:multisynk/models/fixed_expense.dart';
import 'package:multisynk/models/receivable.dart';
import 'package:multisynk/models/transaction.dart';

Transaction tx(String id, double amount, DateTime date,
        {TransactionType type = TransactionType.expense, String? vehicleId}) =>
    Transaction(id: id, description: id, amount: amount, type: type, date: date, vehicleId: vehicleId);

Receivable rec(String id, double expected, DateTime date,
        {ReceivableStatus status = ReceivableStatus.pending, double? received}) =>
    Receivable(id: id, description: id, expectedAmount: expected, receivedAmount: received, expectedDate: date, status: status);

void main() {
  // Wednesday, 14 Oct 2026 15:00. The week started Monday the 12th; October has 31 days.
  final now = DateTime(2026, 10, 14, 15);

  group('computeBudget', () {
    final transactions = [
      tx('salary', 5000, DateTime(2026, 10, 5), type: TransactionType.income),
      tx('early-month', 1000, DateTime(2026, 10, 3)),
      tx('monday', 200, DateTime(2026, 10, 13)),
      tx('today', 100, DateTime(2026, 10, 14, 10)),
      tx('installment-2-later-this-month', 300, DateTime(2026, 10, 20)),
      tx('installment-3-next-month', 300, DateTime(2026, 11, 14)),
      tx('fiorino-fuel', 500, DateTime(2026, 10, 13), vehicleId: 'fiorino-001'),
      tx('meriva-fuel', 50, DateTime(2026, 10, 13), vehicleId: 'meriva-001'),
      tx(fixedExpenseTransactionId('rent', now), 400, DateTime(2026, 10, 1)),
      tx('last-month', 999, DateTime(2026, 9, 30)),
    ];
    final receivables = [
      rec('due-this-month', 1000, DateTime(2026, 10, 25)),
      rec('due-in-december', 2000, DateTime(2026, 12, 1)),
      rec('overdue-partial', 500, DateTime(2026, 9, 10), status: ReceivableStatus.partial, received: 300),
      rec('already-received', 700, DateTime(2026, 10, 2), status: ReceivableStatus.received, received: 700),
    ];
    final fixed = [
      const FixedExpense(id: 'rent', description: 'Aluguel', amount: 400, scope: 'personal'),
      const FixedExpense(id: 'internet', description: 'Internet', amount: 150, scope: 'personal'),
      const FixedExpense(id: 'old', description: 'Cancelado', amount: 999, scope: 'personal', isActive: false),
    ];

    final b = computeBudget(
      now: now,
      transactions: transactions,
      receivables: receivables,
      personalFixed: fixed,
      fiorinoMonthAvailable: 600,
      studioMonthProlabore: 400,
    );

    test('month income = personal + Fiorino available + Studio pró-labore', () {
      expect(b.monthIncome, 6000);
    });

    test('month expenses include later installments of this month but not next month, nor the Fiorino', () {
      expect(b.monthExpenses, 1000 + 200 + 100 + 300 + 50 + 400);
    });

    test('week spending covers Monday..today only (no future installments)', () {
      expect(b.weekSpent, 200 + 100 + 50);
    });

    test('receivables: only money due up to the end of this month, net of what was received', () {
      expect(b.receivablesDue, 1000 + 200);
    });

    test('pending fixed: active and not yet applied this month', () {
      expect(b.pendingFixed, 150);
    });

    test('weekly budget splits the money as it stood at the start of the week', () {
      expect(b.weeksLeft, 3);
      expect(b.available, 6000 + 1200 - 2050 - 150);
      expect(b.weeklyBudget, 1433.33); // (5000 + 350) / 3 - 350
    });
  });

  test('a week that started last month only counts this month\'s spending', () {
    final friday = DateTime(2026, 10, 2, 9);
    final b = computeBudget(
      now: friday,
      transactions: [
        tx('income', 3100, DateTime(2026, 10, 1), type: TransactionType.income),
        tx('september-monday', 100, DateTime(2026, 9, 29)),
        tx('october-thursday', 50, DateTime(2026, 10, 1)),
      ],
      receivables: const [],
      personalFixed: const [],
    );
    expect(b.weekSpent, 50);
    expect(b.monthExpenses, 50);
    expect(b.weeksLeft, 5);
    expect(b.weeklyBudget, 570); // (3050 + 50) / 5 - 50
  });

  test('budget can go negative and is rounded to cents', () {
    final b = computeBudget(
      now: now,
      transactions: [
        tx('income', 100, DateTime(2026, 10, 1), type: TransactionType.income),
        tx('big', 1000, DateTime(2026, 10, 14)),
      ],
      receivables: const [],
      personalFixed: const [],
    );
    expect(b.weeklyBudget, closeTo(-1000 + (100 - 1000 + 1000) / 3, 0.005));
    expect(b.weeklyBudget < 0, isTrue);
    expect((b.weeklyBudget * 100).roundToDouble(), b.weeklyBudget * 100);
  });

  test('weeksLeftInMonth counts today and started weeks', () {
    expect(weeksLeftInMonth(DateTime(2026, 10, 31, 23)), 1);
    expect(weeksLeftInMonth(DateTime(2026, 10, 25)), 1); // 7 days left
    expect(weeksLeftInMonth(DateTime(2026, 10, 24)), 2); // 8 days left
    expect(weeksLeftInMonth(DateTime(2026, 2, 1)), 4);
    expect(weeksLeftInMonth(DateTime(2026, 10, 1)), 5);
  });

  test('empty data gives zero budget, never a division error', () {
    final b = computeBudget(now: now, transactions: const [], receivables: const [], personalFixed: const []);
    expect(b.weeklyBudget, 0);
    expect(b.weeklyBudget.isFinite, isTrue);
  });
}
