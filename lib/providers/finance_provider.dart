import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../models/receivable.dart';

class FinanceState {
  final List<Transaction> transactions;
  final List<Receivable> receivables;
  final bool isLoading;

  const FinanceState({
    this.transactions = const [],
    this.receivables = const [],
    this.isLoading = false,
  });

  double get totalIncome => transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amount);

  // Meriva (id: 'meriva-001') is a family car — its expenses count for the household.
  // Fiorino (id: 'fiorino-001') is business only — tracked separately in FiorinoScreen.
  double get totalExpenses => transactions
      .where((t) => t.type == TransactionType.expense &&
                    (t.vehicleId == null || t.vehicleId == 'meriva-001'))
      .fold(0, (sum, t) => sum + t.amount);

  double get pendingReceivables => receivables
      .where((r) => r.status != ReceivableStatus.received)
      .fold(0, (sum, r) => sum + r.amountToReceive);

  // Mensais — usados no dashboard
  List<Transaction> get thisMonthTransactions {
    final now = DateTime.now();
    return transactions.where((t) => t.date.year == now.year && t.date.month == now.month).toList();
  }

  double get monthIncome => thisMonthTransactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amount);

  double get monthExpenses => thisMonthTransactions
      .where((t) => t.type == TransactionType.expense &&
                    (t.vehicleId == null || t.vehicleId == 'meriva-001'))
      .fold(0, (sum, t) => sum + t.amount);

  // Despesas desta semana (segunda a hoje)
  double get weekExpenses {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            !t.date.isBefore(weekStart) &&
            (t.vehicleId == null || t.vehicleId == 'meriva-001'))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  int get weeksUntilMonthEnd {
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    final days = endOfMonth.difference(now).inDays;
    return (days / 7).ceil().clamp(1, 5);
  }

  // weeklyBudget agora é calculado no HomeScreen integrando Fiorino + Studio.
  // Este getter permanece para compatibilidade mas usa apenas Finance.
  double get weeklyBudget {
    final available = monthIncome + pendingReceivables - monthExpenses;
    final wl = weeksUntilMonthEnd;
    return (available / wl) - weekExpenses;
  }

  FinanceState copyWith({
    List<Transaction>? transactions,
    List<Receivable>? receivables,
    bool? isLoading,
  }) => FinanceState(
    transactions: transactions ?? this.transactions,
    receivables: receivables ?? this.receivables,
    isLoading: isLoading ?? this.isLoading,
  );
}

class FinanceNotifier extends StateNotifier<FinanceState> {
  FinanceNotifier() : super(const FinanceState(isLoading: true)) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final transactions = await DatabaseHelper.instance.getTransactions();
    final receivables = await DatabaseHelper.instance.getReceivables();
    state = FinanceState(transactions: transactions, receivables: receivables);
  }

  Future<void> addTransaction(Transaction t) async {
    await DatabaseHelper.instance.insertTransaction(t);
    await load();
  }

  Future<void> deleteTransaction(String id) async {
    await DatabaseHelper.instance.deleteTransaction(id);
    await load();
  }

  Future<void> addReceivable(Receivable r) async {
    await DatabaseHelper.instance.insertReceivable(r);
    await load();
  }

  Future<void> markReceivableReceived(Receivable r) async {
    final updated = Receivable(
      id: r.id,
      description: r.description,
      expectedAmount: r.expectedAmount,
      receivedAmount: r.expectedAmount,
      expectedDate: r.expectedDate,
      status: ReceivableStatus.received,
      isRecurring: r.isRecurring,
    );
    await DatabaseHelper.instance.updateReceivable(updated);
    await load();
  }

  Future<void> deleteReceivable(String id) async {
    await DatabaseHelper.instance.deleteReceivable(id);
    await load();
  }
}

final financeProvider = StateNotifierProvider<FinanceNotifier, FinanceState>(
  (ref) => FinanceNotifier(),
);
