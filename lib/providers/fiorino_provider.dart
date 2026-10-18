import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/fiorino_entry.dart';

class FiorinoState {
  final List<FiorinoEntry> entries;
  final FiorinoConfig config;
  final bool isLoading;

  const FiorinoState({
    this.entries = const [],
    this.config = const FiorinoConfig(),
    this.isLoading = false,
  });

  // Totais gerais
  double get totalEarned         => entries.fold(0, (s, e) => s + e.amount);
  double get totalToSafety       => entries.fold(0, (s, e) => s + e.toSafety);
  double get totalToMaintenance  => entries.fold(0, (s, e) => s + e.toMaintenance);
  double get totalToFuel         => entries.fold(0, (s, e) => s + e.toFuel);
  double get totalAvailable      => entries.fold(0, (s, e) => s + e.available);

  // Totais do mês atual
  List<FiorinoEntry> get thisMonthEntries {
    final now = DateTime.now();
    return entries.where((e) => e.date.year == now.year && e.date.month == now.month).toList();
  }

  double get monthEarned        => thisMonthEntries.fold(0, (s, e) => s + e.amount);
  double get monthToSafety      => thisMonthEntries.fold(0, (s, e) => s + e.toSafety);
  double get monthToMaintenance => thisMonthEntries.fold(0, (s, e) => s + e.toMaintenance);
  double get monthToFuel        => thisMonthEntries.fold(0, (s, e) => s + e.toFuel);
  double get monthAvailable     => thisMonthEntries.fold(0, (s, e) => s + e.available);

  // Totais da semana (weekStart = segunda-feira da semana)
  List<FiorinoEntry> weekEntries(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return entries.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      return !d.isBefore(weekStart) && d.isBefore(weekEnd);
    }).toList();
  }

  double weekEarned(DateTime ws)        => weekEntries(ws).fold(0, (s, e) => s + e.amount);
  double weekToSafety(DateTime ws)      => weekEntries(ws).fold(0, (s, e) => s + e.toSafety);
  double weekToMaintenance(DateTime ws) => weekEntries(ws).fold(0, (s, e) => s + e.toMaintenance);
  double weekToFuel(DateTime ws)        => weekEntries(ws).fold(0, (s, e) => s + e.toFuel);
  double weekAvailable(DateTime ws)     => weekEntries(ws).fold(0, (s, e) => s + e.available);

  // Entrada de hoje
  FiorinoEntry? get todayEntry {
    final today = DateTime.now();
    try {
      return entries.firstWhere(
        (e) => e.date.year == today.year && e.date.month == today.month && e.date.day == today.day,
      );
    } catch (_) {
      return null;
    }
  }

  FiorinoState copyWith({
    List<FiorinoEntry>? entries,
    FiorinoConfig? config,
    bool? isLoading,
  }) => FiorinoState(
    entries: entries ?? this.entries,
    config: config ?? this.config,
    isLoading: isLoading ?? this.isLoading,
  );
}

class FiorinoNotifier extends StateNotifier<FiorinoState> {
  FiorinoNotifier() : super(const FiorinoState(isLoading: true)) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final entries = await DatabaseHelper.instance.getFiorinoEntries();
    final config = await DatabaseHelper.instance.getFiorinoConfig();
    state = FiorinoState(entries: entries, config: config);
  }

  Future<void> addEntry(double amount, {String? notes, DateTime? date}) async {
    final entry = FiorinoEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      date: date ?? DateTime.now(),
      notes: notes,
      safetyPercent: state.config.safetyPercent,
      maintenancePercent: state.config.maintenancePercent,
      fuelPercent: state.config.fuelPercent,
    );
    await DatabaseHelper.instance.insertFiorinoEntry(entry);
    await load();
  }

  Future<void> deleteEntry(String id) async {
    await DatabaseHelper.instance.deleteFiorinoEntry(id);
    await load();
  }

  Future<void> updateConfig(FiorinoConfig config) async {
    await DatabaseHelper.instance.saveFiorinoConfig(config);
    state = state.copyWith(config: config);
  }
}

final fiorinoProvider = StateNotifierProvider<FiorinoNotifier, FiorinoState>(
  (ref) => FiorinoNotifier(),
);
