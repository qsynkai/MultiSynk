import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/studio_entry.dart';
import '../models/studio_config.dart';

class StudioState {
  final List<StudioEntry> entries;
  final StudioConfig config;
  final bool isLoading;

  const StudioState({
    this.entries = const [],
    this.config = const StudioConfig(),
    this.isLoading = false,
  });

  // ── Entradas do mês atual ───────────────────────────────────
  List<StudioEntry> get thisMonthEntries {
    final now = DateTime.now();
    return entries.where((e) => e.date.year == now.year && e.date.month == now.month).toList();
  }

  double get monthRevenue  => thisMonthEntries.where((e) => e.isRevenue).fold(0, (s, e) => s + e.amount);
  double get monthExpenses => thisMonthEntries.where((e) => e.isExpense).fold(0, (s, e) => s + e.amount);
  double get monthProfit   => monthRevenue - monthExpenses;

  // ── Cofrinhos — calculados sobre o faturamento bruto do mês ─
  double get monthToSafety  => monthRevenue * config.safetyPercent;
  double get monthToSavings => monthRevenue * config.savingsPercent;
  double get monthAvailable => monthRevenue * config.availablePercent - monthExpenses;
  double get monthProlabore => monthAvailable.clamp(0.0, double.infinity);

  // ── Totais históricos ────────────────────────────────────────
  double get totalRevenue  => entries.where((e) => e.isRevenue).fold(0, (s, e) => s + e.amount);
  double get totalExpenses => entries.where((e) => e.isExpense).fold(0, (s, e) => s + e.amount);

  double get totalToSafety  => totalRevenue * config.safetyPercent;
  double get totalToSavings => totalRevenue * config.savingsPercent;

  // ── Totais da semana ─────────────────────────────────────────
  List<StudioEntry> weekEntries(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return entries.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      return !d.isBefore(weekStart) && d.isBefore(weekEnd);
    }).toList();
  }

  double weekRevenue(DateTime ws)  => weekEntries(ws).where((e) => e.isRevenue).fold(0, (s, e) => s + e.amount);
  double weekExpenses(DateTime ws) => weekEntries(ws).where((e) => e.isExpense).fold(0, (s, e) => s + e.amount);
  double weekToSafety(DateTime ws)  => weekRevenue(ws) * config.safetyPercent;
  double weekToSavings(DateTime ws) => weekRevenue(ws) * config.savingsPercent;
  double weekProlabore(DateTime ws) => (weekRevenue(ws) * config.availablePercent - weekExpenses(ws)).clamp(0.0, double.infinity);

  // ── Filtros de lista ─────────────────────────────────────────
  List<StudioEntry> get revenueEntries => entries.where((e) => e.isRevenue).toList();
  List<StudioEntry> get expenseEntries => entries.where((e) => e.isExpense).toList();

  bool get hasTodayRevenue {
    final today = DateTime.now();
    return entries.any((e) =>
        e.isRevenue &&
        e.date.year == today.year &&
        e.date.month == today.month &&
        e.date.day == today.day);
  }

  double get todayRevenue {
    final today = DateTime.now();
    return entries
        .where((e) =>
            e.isRevenue &&
            e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day)
        .fold(0, (s, e) => s + e.amount);
  }

  StudioState copyWith({
    List<StudioEntry>? entries,
    StudioConfig? config,
    bool? isLoading,
  }) => StudioState(
    entries: entries ?? this.entries,
    config:  config  ?? this.config,
    isLoading: isLoading ?? this.isLoading,
  );
}

class StudioNotifier extends StateNotifier<StudioState> {
  StudioNotifier() : super(const StudioState(isLoading: true)) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final entries = await DatabaseHelper.instance.getStudioEntries();
    final config  = await DatabaseHelper.instance.getStudioConfig();
    state = StudioState(entries: entries, config: config);
  }

  Future<void> updateConfig(StudioConfig config) async {
    await DatabaseHelper.instance.saveStudioConfig(config);
    state = state.copyWith(config: config);
  }

  Future<void> addEntry({
    required double amount,
    required String type,
    required String description,
    String? category,
    DateTime? date,
    String? notes,
  }) async {
    final entry = StudioEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      type: type,
      description: description,
      category: category,
      date: date ?? DateTime.now(),
      notes: notes,
    );
    await DatabaseHelper.instance.insertStudioEntry(entry);
    await load();
  }

  Future<void> deleteEntry(String id) async {
    await DatabaseHelper.instance.deleteStudioEntry(id);
    await load();
  }
}

final studioProvider = StateNotifierProvider<StudioNotifier, StudioState>(
  (ref) => StudioNotifier(),
);
