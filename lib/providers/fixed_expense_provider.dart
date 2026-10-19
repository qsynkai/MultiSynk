import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/fixed_expense.dart';
import '../models/fixed_expense_payment.dart';

class FixedExpenseState {
  final List<FixedExpense> expenses;
  final List<FixedExpensePayment> payments;
  final bool isLoading;

  const FixedExpenseState({
    this.expenses = const [],
    this.payments = const [],
    this.isLoading = false,
  });

  List<FixedExpense> get studioExpenses  => expenses.where((e) => e.scope == 'studio'   && e.isActive).toList();
  List<FixedExpense> get personalExpenses => expenses.where((e) => e.scope == 'personal' && e.isActive).toList();

  double get studioTotal   => studioExpenses.fold(0, (s, e) => s + e.amount);
  double get personalTotal => personalExpenses.fold(0, (s, e) => s + e.amount);

  /// IDs of fixed expenses that are already paid for [year]/[month].
  Set<String> paidIds(int year, int month) => {
    for (final p in payments)
      if (p.year == year && p.month == month) p.fixedExpenseId,
  };

  bool isPaid(String expenseId, int year, int month) =>
      payments.any((p) => p.fixedExpenseId == expenseId && p.year == year && p.month == month);

  FixedExpenseState copyWith({
    List<FixedExpense>? expenses,
    List<FixedExpensePayment>? payments,
    bool? isLoading,
  }) => FixedExpenseState(
    expenses: expenses ?? this.expenses,
    payments: payments ?? this.payments,
    isLoading: isLoading ?? this.isLoading,
  );
}

class FixedExpenseNotifier extends StateNotifier<FixedExpenseState> {
  FixedExpenseNotifier() : super(const FixedExpenseState(isLoading: true)) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final expenses = await DatabaseHelper.instance.getFixedExpenses();
    final payments = await DatabaseHelper.instance.getFixedExpensePayments();
    state = FixedExpenseState(expenses: expenses, payments: payments);
  }

  Future<void> add(FixedExpense expense) async {
    await DatabaseHelper.instance.insertFixedExpense(expense);
    await load();
  }

  Future<void> toggle(String id) async {
    final expense = state.expenses.firstWhere((e) => e.id == id);
    await DatabaseHelper.instance.updateFixedExpense(expense.copyWith(isActive: !expense.isActive));
    await load();
  }

  Future<void> delete(String id) async {
    await DatabaseHelper.instance.deleteFixedExpense(id);
    await load();
  }

  /// Marks a fixed expense as paid for a given month.
  Future<void> markPaid(String expenseId, int year, int month) async {
    final payment = FixedExpensePayment(
      id: const Uuid().v4(),
      fixedExpenseId: expenseId,
      year: year,
      month: month,
      paidAt: DateTime.now(),
    );
    await DatabaseHelper.instance.upsertFixedExpensePayment(payment);
    await load();
  }

  /// Removes the paid status for a fixed expense in a given month.
  Future<void> unmarkPaid(String expenseId, int year, int month) async {
    await DatabaseHelper.instance.deleteFixedExpensePayment(expenseId, year, month);
    await load();
  }
}

final fixedExpenseProvider = StateNotifierProvider<FixedExpenseNotifier, FixedExpenseState>(
  (ref) => FixedExpenseNotifier(),
);
