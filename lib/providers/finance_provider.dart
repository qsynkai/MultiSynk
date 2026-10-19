import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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

  Future<void> addTransactions(List<Transaction> list) async {
    for (final t in list) {
      await DatabaseHelper.instance.insertTransaction(t);
    }
    await load();
  }

  Future<void> updateTransaction(Transaction t) async {
    await DatabaseHelper.instance.updateTransaction(t);
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

  /// Marks the receivable as received AND creates a corresponding income Transaction.
  Future<void> markReceivableReceived(Receivable r) async {
    final txId = const Uuid().v4();
    final tx = Transaction(
      id: txId,
      description: r.description,
      amount: r.expectedAmount,
      type: TransactionType.income,
      date: DateTime.now(),
      category: 'recebimento',
    );
    await DatabaseHelper.instance.insertTransaction(tx);
    final updated = r.copyWith(
      status: ReceivableStatus.received,
      receivedAmount: r.expectedAmount,
      linkedTransactionId: txId,
    );
    await DatabaseHelper.instance.updateReceivable(updated);
    await load();
  }

  /// Reverts a received receivable back to pending and deletes the linked income Transaction.
  Future<void> unmarkReceivableReceived(Receivable r) async {
    if (r.linkedTransactionId != null) {
      await DatabaseHelper.instance.deleteTransaction(r.linkedTransactionId!);
    }
    final updated = r.copyWith(
      status: ReceivableStatus.pending,
      receivedAmount: 0,
      clearLinkedTransaction: true,
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
