import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/fixed_expense.dart';

class FixedExpenseState {
  final List<FixedExpense> expenses;
  final bool isLoading;

  const FixedExpenseState({this.expenses = const [], this.isLoading = false});

  List<FixedExpense> get studioExpenses  => expenses.where((e) => e.scope == 'studio'   && e.isActive).toList();
  List<FixedExpense> get personalExpenses => expenses.where((e) => e.scope == 'personal' && e.isActive).toList();

  double get studioTotal   => studioExpenses.fold(0, (s, e) => s + e.amount);
  double get personalTotal => personalExpenses.fold(0, (s, e) => s + e.amount);

  FixedExpenseState copyWith({List<FixedExpense>? expenses, bool? isLoading}) =>
      FixedExpenseState(expenses: expenses ?? this.expenses, isLoading: isLoading ?? this.isLoading);
}

class FixedExpenseNotifier extends StateNotifier<FixedExpenseState> {
  FixedExpenseNotifier() : super(const FixedExpenseState(isLoading: true)) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final expenses = await DatabaseHelper.instance.getFixedExpenses();
    state = FixedExpenseState(expenses: expenses);
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
}

final fixedExpenseProvider = StateNotifierProvider<FixedExpenseNotifier, FixedExpenseState>(
  (ref) => FixedExpenseNotifier(),
);
