import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/fiorino_provider.dart';
import '../models/fiorino_entry.dart';
import '../logic/money.dart';

class FiorinoScreen extends ConsumerStatefulWidget {
  const FiorinoScreen({super.key});

  @override
  ConsumerState<FiorinoScreen> createState() => _FiorinoScreenState();
}

class _FiorinoScreenState extends ConsumerState<FiorinoScreen> {
  String _viewMode = 'semana';
  late DateTime _selectedWeekStart;

  @override
  void initState() {
    super.initState();
    _selectedWeekStart = _startOfWeek(DateTime.now());
  }

  DateTime _startOfWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1)); // segunda-feira
  }

  bool get _isCurrentWeek => _selectedWeekStart == _startOfWeek(DateTime.now());
  bool get _isSunday => DateTime.now().weekday == DateTime.sunday;

  String get _weekLabel {
    final end = _selectedWeekStart.add(const Duration(days: 6));
    final mid = _selectedWeekStart.add(const Duration(days: 3));
    final weekNum = ((mid.day - 1) ~/ 7) + 1;
    final month = DateFormat('MMMM', 'pt_BR').format(mid);
    return 'Semana $weekNum de $month · ${DateFormat('dd/MM').format(_selectedWeekStart)}–${DateFormat('dd/MM').format(end)}';
  }

  void _prevWeek() => setState(() => _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7)));
  void _nextWeek() {
    final next = _selectedWeekStart.add(const Duration(days: 7));
    if (!next.isAfter(_startOfWeek(DateTime.now()))) {
      setState(() => _selectedWeekStart = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fiorinoProvider);
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final isSemana = _viewMode == 'semana';
    final ws = _selectedWeekStart;

    final cofSafety      = isSemana ? state.weekToSafety(ws)      : state.monthToSafety;
    final cofMaintenance = isSemana ? state.weekToMaintenance(ws) : state.monthToMaintenance;
    final cofFuel        = isSemana ? state.weekToFuel(ws)        : state.monthToFuel;
    final cofAvailable   = isSemana ? state.weekAvailable(ws)     : state.monthAvailable;
    final displayEntries = isSemana ? state.weekEntries(ws)       : state.thisMonthEntries;
    final totalEarned    = isSemana ? state.weekEarned(ws)        : state.monthEarned;
    final days           = displayEntries.length;
    final avg            = days > 0 ? totalEarned / days : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textSecondary, size: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fiorino — Trabalho', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                          Text('Entradas diárias e cofrinhos', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showConfigSheet(context, state.config),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
                        ),
                        child: const Icon(Icons.tune_rounded, color: AppColors.textSecondary, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Toggle Semana / Mês
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(child: _ViewToggle(
                      selected: _viewMode,
                      onChanged: (v) => setState(() => _viewMode = v),
                      color: AppColors.success,
                    )),
                  ],
                ),
              ),
            ),

            // Navegador semana / mês
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: isSemana
                    ? _WeekNavigator(
                        label: _weekLabel,
                        onPrev: _prevWeek,
                        onNext: _isCurrentWeek ? null : _nextWeek,
                        color: AppColors.success,
                      )
                    : _MonthLabel(month: DateTime.now(), color: AppColors.success),
              ),
            ),

            // Banner de domingo
            if (isSemana && _isCurrentWeek && _isSunday)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _SundayBanner(
                    safety: cofSafety,
                    maintenance: cofMaintenance,
                    fuel: cofFuel,
                    available: cofAvailable,
                    fmt: fmt,
                    color: AppColors.success,
                    labels: const ['Segurança', 'Manutenção', 'Combustível'],
                  ),
                ),
              ),

            // Entrada do dia
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _DailyEntryCard(state: state, fmt: fmt),
              ),
            ),

            // Cofrinhos
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Text(
                  isSemana ? 'Cofrinhos da semana' : 'Cofrinhos do mês',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    _CofrinhoCard(
                      label: 'Caixa de segurança',
                      subtitle: '${(state.config.safetyPercent * 100).toStringAsFixed(0)}% de cada entrada',
                      value: cofSafety,
                      totalValue: state.totalToSafety,
                      color: AppColors.success,
                      icon: Icons.shield_rounded,
                      fmt: fmt,
                    ),
                    const SizedBox(height: 10),
                    _CofrinhoCard(
                      label: 'Manutenção Fiorino',
                      subtitle: '${(state.config.maintenancePercent * 100).toStringAsFixed(0)}% de cada entrada',
                      value: cofMaintenance,
                      totalValue: state.totalToMaintenance,
                      color: AppColors.accent,
                      icon: Icons.build_rounded,
                      fmt: fmt,
                    ),
                    const SizedBox(height: 10),
                    _CofrinhoCard(
                      label: 'Combustível',
                      subtitle: '${(state.config.fuelPercent * 100).toStringAsFixed(0)}% de cada entrada',
                      value: cofFuel,
                      totalValue: state.totalToFuel,
                      color: const Color(0xFFFFA500),
                      icon: Icons.local_gas_station_rounded,
                      fmt: fmt,
                    ),
                    const SizedBox(height: 10),
                    _CofrinhoCard(
                      label: 'Disponível',
                      subtitle: '${(state.config.availablePercent * 100).toStringAsFixed(0)}% de cada entrada',
                      value: cofAvailable,
                      totalValue: state.totalAvailable,
                      color: AppColors.primary,
                      icon: Icons.account_balance_wallet_rounded,
                      fmt: fmt,
                    ),
                  ],
                ),
              ),
            ),

            // Resumo
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _PeriodSummaryCard(
                  label: isSemana ? 'Resumo da semana' : 'Resumo do mês',
                  total: totalEarned,
                  days: days,
                  avg: avg,
                  fmt: fmt,
                ),
              ),
            ),

            // Histórico
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isSemana ? 'Entradas da semana' : 'Entradas do mês',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text('${displayEntries.length} entradas', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ),

            if (displayEntries.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: Text('Nenhuma entrada no período', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: _EntryHistoryTile(entry: displayEntries[i], fmt: fmt),
                  ),
                  childCount: displayEntries.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  void _showConfigSheet(BuildContext context, FiorinoConfig config) {
    double safety = config.safetyPercent;
    double maintenance = config.maintenancePercent;
    double fuel = config.fuelPercent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final available = ((1.0 - safety - maintenance - fuel) * 100).round();
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Configurar percentuais', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Defina quanto de cada entrada vai para cada cofrinho.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 20),

                _PercentSlider(
                  label: 'Caixa de segurança',
                  color: AppColors.success,
                  icon: Icons.shield_rounded,
                  value: safety,
                  onChanged: (v) => setState(() => safety = v),
                ),
                const SizedBox(height: 16),
                _PercentSlider(
                  label: 'Manutenção Fiorino',
                  color: AppColors.accent,
                  icon: Icons.build_rounded,
                  value: maintenance,
                  onChanged: (v) => setState(() => maintenance = v),
                ),
                const SizedBox(height: 16),
                _PercentSlider(
                  label: 'Combustível',
                  color: const Color(0xFFFFA500),
                  icon: Icons.local_gas_station_rounded,
                  value: fuel,
                  onChanged: (v) => setState(() => fuel = v),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: available < 0 ? AppColors.danger.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: available < 0 ? AppColors.danger.withOpacity(0.3) : AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: available < 0 ? AppColors.danger : AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Disponível: $available%',
                          style: TextStyle(
                            color: available < 0 ? AppColors.danger : AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (available < 0)
                        const Text('Reduz os %', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: available < 0
                      ? null
                      : () {
                          ref.read(fiorinoProvider.notifier).updateConfig(
                            FiorinoConfig(safetyPercent: safety, maintenancePercent: maintenance, fuelPercent: fuel),
                          );
                          Navigator.pop(ctx);
                        },
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Salvar configuração'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DailyEntryCard extends ConsumerWidget {
  final FiorinoState state;
  final NumberFormat fmt;

  const _DailyEntryCard({required this.state, required this.fmt});

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = state.todayEntry;
    final hasEntry = today != null;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2A1A), Color(0xFF0D1A0D)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withOpacity(0.25), width: 0.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.today_rounded, color: Colors.white.withOpacity(0.6), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('EEEE, dd/MM', 'pt_BR').format(DateTime.now()).toUpperCase(),
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasEntry) ...[
            Text('Entrada registrada', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
            const SizedBox(height: 4),
            Text(fmt.format(today.amount), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, height: 1.1)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(child: _MiniStat(label: 'Segurança', value: fmt.format(today.toSafety), color: AppColors.success)),
                  Container(width: 0.5, height: 28, color: Colors.white.withOpacity(0.15)),
                  Expanded(child: _MiniStat(label: 'Manutenção', value: fmt.format(today.toMaintenance), color: AppColors.accent)),
                  Container(width: 0.5, height: 28, color: Colors.white.withOpacity(0.15)),
                  Expanded(child: _MiniStat(label: 'Combustível', value: fmt.format(today.toFuel), color: const Color(0xFFFFA500))),
                  Container(width: 0.5, height: 28, color: Colors.white.withOpacity(0.15)),
                  Expanded(child: _MiniStat(label: 'Disponível', value: fmt.format(today.available), color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                ref.read(fiorinoProvider.notifier).deleteEntry(today.id);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_outlined, color: Colors.white.withOpacity(0.4), size: 14),
                  const SizedBox(width: 4),
                  Text('Remover entrada de hoje', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                ],
              ),
            ),
          ] else ...[
            Text('Quanto entrou hoje?', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showAddEntry(context, ref),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.success.withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_rounded, color: AppColors.success, size: 20),
                    SizedBox(width: 8),
                    Text('Registrar entrada do dia', style: TextStyle(color: AppColors.success, fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddEntry(BuildContext context, WidgetRef ref) {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final amount = parseMoney(amountCtrl.text) ?? 0;
          final safety = amount * state.config.safetyPercent;
          final maintenance = amount * state.config.maintenancePercent;
          final available = amount * state.config.availablePercent;
          final isToday = _isSameDay(selectedDate, DateTime.now());
          final dateLabel = isToday
              ? 'Hoje, ${DateFormat('dd/MM', 'pt_BR').format(selectedDate)}'
              : DateFormat("EEE, dd/MM", 'pt_BR').format(selectedDate);

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Entrada — Fiorino', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                          builder: (c, child) => Theme(
                            data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.success)),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isToday ? AppColors.surfaceLight : AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isToday ? AppColors.surfaceBorder : AppColors.success.withOpacity(0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: isToday ? AppColors.textMuted : AppColors.success),
                            const SizedBox(width: 6),
                            Text(dateLabel, style: TextStyle(color: isToday ? AppColors.textSecondary : AppColors.success, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    labelText: 'Quanto entrou?',
                    prefixText: 'R\$ ',
                    prefixStyle: TextStyle(color: AppColors.success, fontSize: 22, fontWeight: FontWeight.w600),
                    hintText: '0,00',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
                if (amount > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _SplitRow(
                          label: 'Caixa de segurança',
                          percent: state.config.safetyPercent,
                          value: safety,
                          color: AppColors.success,
                          fmt: NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$'),
                        ),
                        const SizedBox(height: 8),
                        _SplitRow(
                          label: 'Manutenção Fiorino',
                          percent: state.config.maintenancePercent,
                          value: maintenance,
                          color: AppColors.accent,
                          fmt: NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$'),
                        ),
                        const Divider(height: 16),
                        _SplitRow(
                          label: 'Disponível para você',
                          percent: state.config.availablePercent,
                          value: available,
                          color: AppColors.primary,
                          fmt: NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$'),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Observação (opcional)', hintText: 'ex: Dia cheio, choveu à tarde...'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: amount <= 0 ? null : () {
                    ref.read(fiorinoProvider.notifier).addEntry(
                      amount,
                      notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                      date: selectedDate,
                    );
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.success,
                  ),
                  child: const Text('Registrar', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CofrinhoCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final double value;
  final double totalValue;
  final Color color;
  final IconData icon;
  final NumberFormat fmt;

  const _CofrinhoCard({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.totalValue,
    required this.color,
    required this.icon,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmt.format(value), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
              Text('Total: ${fmt.format(totalValue)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodSummaryCard extends StatelessWidget {
  final String label;
  final double total;
  final int days;
  final double avg;
  final NumberFormat fmt;

  const _PeriodSummaryCard({
    required this.label,
    required this.total,
    required this.days,
    required this.avg,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SummaryTile(label: 'Total bruto', value: fmt.format(total), color: AppColors.textPrimary)),
              Expanded(child: _SummaryTile(label: 'Dias', value: '$days dias', color: AppColors.textPrimary)),
              Expanded(child: _SummaryTile(label: 'Média/dia', value: fmt.format(avg), color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Widgets compartilhados semana/mês ────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final Color color;

  const _ViewToggle({required this.selected, required this.onChanged, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
      ),
      child: Row(
        children: [
          _ToggleBtn(label: 'Semana', value: 'semana', selected: selected, onTap: () => onChanged('semana'), color: color),
          _ToggleBtn(label: 'Mês', value: 'mes', selected: selected, onTap: () => onChanged('mes'), color: color),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label, value, selected;
  final VoidCallback onTap;
  final Color color;

  const _ToggleBtn({required this.label, required this.value, required this.selected, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    final isActive = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? color : AppColors.textMuted,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekNavigator extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final Color color;

  const _WeekNavigator({required this.label, required this.onPrev, this.onNext, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onPrev,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.surfaceBorder, width: 0.5)),
            child: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 20),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
        GestureDetector(
          onTap: onNext,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: onNext == null ? AppColors.surface.withOpacity(0.4) : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
            ),
            child: Icon(Icons.chevron_right_rounded, color: onNext == null ? AppColors.textMuted : AppColors.textSecondary, size: 20),
          ),
        ),
      ],
    );
  }
}

class _MonthLabel extends StatelessWidget {
  final DateTime month;
  final Color color;

  const _MonthLabel({required this.month, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        DateFormat('MMMM yyyy', 'pt_BR').format(month).toUpperCase(),
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6),
      ),
    );
  }
}

class _SundayBanner extends StatelessWidget {
  final double safety;
  final double maintenance;
  final double fuel;
  final double available;
  final NumberFormat fmt;
  final Color color;
  final List<String> labels;

  const _SundayBanner({
    required this.safety,
    required this.maintenance,
    required this.fuel,
    required this.available,
    required this.fmt,
    required this.color,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final total = safety + maintenance + fuel;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.18), color.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.savings_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fechamento semanal', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
                    Text('Hoje é domingo — hora de depositar os cofrinhos!', style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _BannerChip(label: labels[0], value: fmt.format(safety), color: AppColors.success),
              const SizedBox(width: 6),
              _BannerChip(label: labels[1], value: fmt.format(maintenance), color: AppColors.accent),
              const SizedBox(width: 6),
              _BannerChip(label: labels[2], value: fmt.format(fuel), color: const Color(0xFFFFA500)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total a depositar', style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
                Text(fmt.format(total), style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BannerChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ],
    );
  }
}

class _EntryHistoryTile extends ConsumerWidget {
  final FiorinoEntry entry;
  final NumberFormat fmt;

  const _EntryHistoryTile({required this.entry, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isToday = () {
      final now = DateTime.now();
      return entry.date.year == now.year && entry.date.month == now.month && entry.date.day == now.day;
    }();

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
      ),
      onDismissed: (_) => ref.read(fiorinoProvider.notifier).deleteEntry(entry.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday ? AppColors.success.withOpacity(0.3) : AppColors.surfaceBorder,
            width: isToday ? 1 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  DateFormat('dd/MM/yyyy (EEE)', 'pt_BR').format(entry.date),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                if (isToday) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('hoje', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ],
                const Spacer(),
                Text(fmt.format(entry.amount), style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MiniChip(label: '${fmt.format(entry.toSafety)} seg.', color: AppColors.success),
                const SizedBox(width: 4),
                _MiniChip(label: '${fmt.format(entry.toMaintenance)} manut.', color: AppColors.accent),
                const SizedBox(width: 4),
                _MiniChip(label: '${fmt.format(entry.toFuel)} comb.', color: const Color(0xFFFFA500)),
                const SizedBox(width: 4),
                _MiniChip(label: '${fmt.format(entry.available)} livre', color: AppColors.primary),
              ],
            ),
            if (entry.notes != null) ...[
              const SizedBox(height: 6),
              Text(entry.notes!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SplitRow extends StatelessWidget {
  final String label;
  final double percent;
  final double value;
  final Color color;
  final NumberFormat fmt;
  final bool bold;

  const _SplitRow({required this.label, required this.percent, required this.value, required this.color, required this.fmt, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: bold ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 13, fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
          ),
        ),
        Text(
          '${(percent * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(width: 10),
        Text(
          fmt.format(value),
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _PercentSlider extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  const _PercentSlider({required this.label, required this.color, required this.icon, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${(value * 100).round()}%', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
            thumbColor: color,
            overlayColor: color.withOpacity(0.1),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 0.5,
            divisions: 50,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
