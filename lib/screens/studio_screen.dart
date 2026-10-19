import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../providers/studio_provider.dart';
import '../providers/fixed_expense_provider.dart';
import '../models/studio_entry.dart';
import '../models/studio_config.dart';
import '../models/fixed_expense.dart';
import '../logic/money.dart';
import '../models/transaction.dart';
import '../models/payment_card.dart';
import '../providers/finance_provider.dart';
import '../providers/payment_card_provider.dart';
import '../widgets/payment_method_selector.dart';

const _studioRose = Color(0xFFD4548A);
const _studioBg = Color(0xFF1A0D14);

const _expenseCategories = [
  'Produtos',
  'Aluguel',
  'Equipamentos',
  'Marketing',
  'Energia/Água',
  'Outros',
];

class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({super.key});

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _viewMode = 'semana';
  late DateTime _selectedWeekStart;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _selectedWeekStart = _startOfWeek(DateTime.now());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  DateTime _startOfWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
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
    if (!next.isAfter(_startOfWeek(DateTime.now()))) setState(() => _selectedWeekStart = next);
  }

  List<StudioEntry> _filterMonth(List<StudioEntry> entries) =>
      entries.where((e) => e.date.year == _selectedMonth.year && e.date.month == _selectedMonth.month).toList();

  void _prevMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));
  void _nextMonth() {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (!next.isAfter(DateTime(DateTime.now().year, DateTime.now().month))) {
      setState(() => _selectedMonth = next);
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioProvider);
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final isSemana = _viewMode == 'semana';

    final monthEntries = _filterMonth(state.entries);
    final mRevenue  = isSemana ? state.weekRevenue(_selectedWeekStart)   : monthEntries.where((e) => e.isRevenue).fold(0.0, (s, e) => s + e.amount);
    final mExpenses = isSemana ? state.weekExpenses(_selectedWeekStart)  : monthEntries.where((e) => e.isExpense).fold(0.0, (s, e) => s + e.amount);
    final mProfit   = mRevenue - mExpenses;
    final mSafety   = isSemana ? state.weekToSafety(_selectedWeekStart)  : mRevenue * state.config.safetyPercent;
    final mSavings  = isSemana ? state.weekToSavings(_selectedWeekStart) : mRevenue * state.config.savingsPercent;
    final mProlabore = isSemana
        ? state.weekProlabore(_selectedWeekStart)
        : (mRevenue * state.config.availablePercent - mExpenses).clamp(0.0, double.infinity);

    final displayEntries = isSemana ? state.weekEntries(_selectedWeekStart) : monthEntries;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _studioRose.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.spa_rounded, color: _studioRose, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ferretti Studio Beauty', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                          Text('Dashboard do estúdio', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showStudioConfigSheet(context, state),
                      child: Container(
                        width: 40, height: 40,
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
                child: _ViewToggle(
                  selected: _viewMode,
                  onChanged: (v) => setState(() => _viewMode = v),
                  color: _studioRose,
                ),
              ),
            ),

            // Navegador semana ou mês
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: isSemana
                    ? _WeekNavigator(
                        label: _weekLabel,
                        onPrev: _prevWeek,
                        onNext: _isCurrentWeek ? null : _nextWeek,
                        color: _studioRose,
                      )
                    : Row(
                        children: [
                          GestureDetector(
                            onTap: _prevMonth,
                            child: Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.surfaceBorder, width: 0.5)),
                              child: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 20),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                DateFormat('MMMM yyyy', 'pt_BR').format(_selectedMonth).toUpperCase(),
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _isCurrentMonth ? null : _nextMonth,
                            child: Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: _isCurrentMonth ? AppColors.surface.withOpacity(0.4) : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
                              ),
                              child: Icon(Icons.chevron_right_rounded, color: _isCurrentMonth ? AppColors.textMuted : AppColors.textSecondary, size: 20),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Banner de domingo
            if (isSemana && _isCurrentWeek && _isSunday)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _SundayBanner(
                    safety: mSafety,
                    maintenance: mSavings,
                    fuel: mProlabore,
                    available: mProlabore,
                    fmt: fmt,
                    color: _studioRose,
                    labels: const ['Segurança', 'Poupança', 'Pró-labore'],
                  ),
                ),
              ),

            // Cards de resumo
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _SummaryCards(revenue: mRevenue, expenses: mExpenses, profit: mProfit, month: _selectedMonth, fmt: fmt),
              ),
            ),

            // Cofrinhos
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isSemana ? 'Cofrinhos da semana' : 'Cofrinhos do mês', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _StudioCofrinhoCard(
                          icon: Icons.shield_rounded,
                          label: 'Caixa de\nSegurança',
                          value: fmt.format(mSafety),
                          percent: (state.config.safetyPercent * 100).round(),
                          color: const Color(0xFF4CAF50),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _StudioCofrinhoCard(
                          icon: Icons.savings_rounded,
                          label: 'Guardar /\nPoupança',
                          value: fmt.format(mSavings),
                          percent: (state.config.savingsPercent * 100).round(),
                          color: const Color(0xFF9C27B0),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _StudioCofrinhoCard(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Pró-labore',
                          value: fmt.format(mProlabore),
                          percent: (state.config.availablePercent * 100).round(),
                          color: _studioRose,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Botões de ação (só no mês atual)
            if (_isCurrentMonth)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showAddEntry(context, 'revenue'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: _studioRose.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _studioRose.withOpacity(0.35)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_rounded, color: _studioRose, size: 18),
                                SizedBox(width: 6),
                                Text('Faturamento', style: TextStyle(color: _studioRose, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showAddEntry(context, 'expense'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.remove_rounded, color: AppColors.danger, size: 18),
                                SizedBox(width: 6),
                                Text('Gasto', style: TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Tabs
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
                  ),
                  child: TabBar(
                    controller: _tab,
                    indicator: BoxDecoration(
                      color: _studioRose.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: _studioRose,
                    unselectedLabelColor: AppColors.textMuted,
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Todos'),
                      Tab(text: 'Faturamento'),
                      Tab(text: 'Gastos'),
                      Tab(text: 'Fixas'),
                      Tab(text: 'Histórico'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tab,
            children: [
              _EntryList(entries: displayEntries, fmt: fmt),
              _EntryList(entries: displayEntries.where((e) => e.isRevenue).toList(), fmt: fmt),
              _EntryList(entries: displayEntries.where((e) => e.isExpense).toList(), fmt: fmt),
              const _StudioFixedTab(),
              _TimelineTab(allEntries: state.entries, config: state.config, fmt: fmt),
            ],
          ),
        ),
      ),
    );
  }

  void _showStudioConfigSheet(BuildContext context, StudioState state) {
    double safety  = state.config.safetyPercent;
    double savings = state.config.savingsPercent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final available = (1.0 - safety - savings).clamp(0.0, 1.0);
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _studioRose.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.tune_rounded, color: _studioRose, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('Configurar cofrinhos', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 20),
                _PercentSlider(
                  label: 'Caixa de Segurança',
                  icon: Icons.shield_rounded,
                  color: const Color(0xFF4CAF50),
                  value: safety,
                  onChanged: (v) => setState(() => safety = v),
                ),
                const SizedBox(height: 16),
                _PercentSlider(
                  label: 'Guardar / Poupança',
                  icon: Icons.savings_rounded,
                  color: const Color(0xFF9C27B0),
                  value: savings,
                  onChanged: (v) => setState(() => savings = v),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _studioRose.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _studioRose.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wallet_rounded, color: _studioRose, size: 16),
                      const SizedBox(width: 8),
                      const Text('Disponível', style: TextStyle(color: _studioRose, fontSize: 13)),
                      const Spacer(),
                      Text('${(available * 100).round()}%', style: const TextStyle(color: _studioRose, fontSize: 15, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    ref.read(studioProvider.notifier).updateConfig(
                      StudioConfig(safetyPercent: safety, savingsPercent: savings),
                    );
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: _studioRose,
                  ),
                  child: const Text('Salvar configuração', style: TextStyle(fontSize: 15)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void _showAddEntry(BuildContext context, String type) {
    final isRevenue = type == 'revenue';
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? selectedCategory = isRevenue ? null : _expenseCategories.first;
    DateTime selectedDate = DateTime.now();
    final cfgFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    PaymentMethod? paymentMethod;
    PaymentCard? selectedCard;
    int installments = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final amount = parseMoney(amountCtrl.text) ?? 0;
          final isToday = _isSameDay(selectedDate, DateTime.now());
          final dateLabel = isToday
              ? 'Hoje, ${DateFormat('dd/MM', 'pt_BR').format(selectedDate)}'
              : DateFormat("EEE, dd/MM", 'pt_BR').format(selectedDate);
          final entryColor = isRevenue ? _studioRose : AppColors.danger;
          final cards = ref.read(paymentCardProvider).cards;

          // cofrinhos preview para receita
          final cfg = ref.read(studioProvider).config;
          final cfgSafety   = amount * cfg.safetyPercent;
          final cfgSavings  = amount * cfg.savingsPercent;
          final cfgAvail    = amount * cfg.availablePercent;

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: entryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isRevenue ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          color: entryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isRevenue ? 'Faturamento do dia' : 'Registrar gasto',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now(),
                            builder: (c, child) => Theme(
                              data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: entryColor)),
                              child: child!,
                            ),
                          );
                          if (picked != null) setState(() => selectedDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isToday ? AppColors.surfaceLight : entryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isToday ? AppColors.surfaceBorder : entryColor.withOpacity(0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 13, color: isToday ? AppColors.textMuted : entryColor),
                              const SizedBox(width: 5),
                              Text(dateLabel, style: TextStyle(color: isToday ? AppColors.textSecondary : entryColor, fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Despesa: campo descrição obrigatório
                  if (!isRevenue) ...[
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Descrição do gasto',
                        hintText: 'ex: Compra de esmaltes',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Campo valor
                  TextField(
                    controller: amountCtrl,
                    style: TextStyle(color: isRevenue ? _studioRose : AppColors.danger, fontSize: 28, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: isRevenue ? 'Quanto faturou?' : 'Valor',
                      prefixText: 'R\$ ',
                      prefixStyle: TextStyle(color: isRevenue ? _studioRose : AppColors.danger, fontSize: 22, fontWeight: FontWeight.w600),
                      hintText: '0,00',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                  ),

                  // Receita: preview dos cofrinhos (igual Fiorino)
                  if (isRevenue && amount > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _StudioSplitRow(
                            label: 'Caixa de segurança',
                            percent: cfg.safetyPercent,
                            value: cfgSafety,
                            color: const Color(0xFF4CAF50),
                            fmt: cfgFmt,
                          ),
                          const SizedBox(height: 8),
                          _StudioSplitRow(
                            label: 'Guardar / Poupança',
                            percent: cfg.savingsPercent,
                            value: cfgSavings,
                            color: const Color(0xFF9C27B0),
                            fmt: cfgFmt,
                          ),
                          const Divider(height: 16),
                          _StudioSplitRow(
                            label: 'Disponível (pró-labore)',
                            percent: cfg.availablePercent,
                            value: cfgAvail,
                            color: _studioRose,
                            fmt: cfgFmt,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Despesa: forma de pagamento e cartão
                  if (!isRevenue) ...[
                    const SizedBox(height: 16),
                    PaymentMethodSelector(
                      selectedMethod: paymentMethod,
                      selectedCard: selectedCard,
                      cards: cards,
                      installments: installments,
                      onMethodChanged: (m) => setState(() { paymentMethod = m; if (m != PaymentMethod.credit) { selectedCard = null; installments = 1; } }),
                      onCardChanged: (c) => setState(() => selectedCard = c),
                      onInstallmentsChanged: (v) => setState(() => installments = v),
                    ),
                  ],

                  // Despesa: categorias
                  if (!isRevenue) ...[
                    const SizedBox(height: 12),
                    const Text('Categoria', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _expenseCategories.map((cat) {
                        final selected = selectedCategory == cat;
                        return GestureDetector(
                          onTap: () => setState(() => selectedCategory = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.danger.withOpacity(0.15) : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? AppColors.danger.withOpacity(0.5) : AppColors.surfaceBorder,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: selected ? AppColors.danger : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Observação (opcional)'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: (isRevenue ? amount <= 0 : (amount <= 0 || descCtrl.text.trim().isEmpty)) ? null : () {
                      final count = installments < 1 ? 1 : installments;
                      final groupId = count > 1 ? const Uuid().v4() : null;
                      final parts = splitInstallments(amount, count);
                      final now = selectedDate;

                      for (int i = 0; i < count; i++) {
                        final partDate = addMonthsClamped(now, i);
                        final desc = isRevenue
                            ? 'Faturamento — ${DateFormat('dd/MM', 'pt_BR').format(selectedDate)}'
                            : count > 1
                                ? '${descCtrl.text.trim()} (${i + 1}/$count)'
                                : descCtrl.text.trim();

                        ref.read(studioProvider.notifier).addEntry(
                          amount: parts[i],
                          type: type,
                          description: desc,
                          category: isRevenue ? null : selectedCategory,
                          notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                          date: partDate,
                          paymentMethod: paymentMethod,
                          cardId: selectedCard?.id,
                          installments: count,
                          installmentNumber: i + 1,
                          installmentGroupId: groupId,
                        );

                        // Cria Transaction correspondente no Finanças para aparecer na fatura do cartão
                        if (!isRevenue && selectedCard != null) {
                          ref.read(financeProvider.notifier).addTransaction(
                            Transaction(
                              id: const Uuid().v4(),
                              description: '[Studio] $desc',
                              amount: parts[i],
                              type: TransactionType.expense,
                              date: partDate,
                              paymentMethod: paymentMethod,
                              cardId: selectedCard?.id,
                              installments: count,
                              installmentNumber: i + 1,
                              installmentGroupId: groupId,
                            ),
                          );
                        }
                      }
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: isRevenue ? _studioRose : AppColors.danger,
                    ),
                    child: Text(
                      isRevenue
                          ? 'Registrar faturamento'
                          : installments > 1
                              ? 'Registrar gasto ($installments parcelas)'
                              : 'Registrar gasto',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final double revenue;
  final double expenses;
  final double profit;
  final DateTime month;
  final NumberFormat fmt;

  const _SummaryCards({required this.revenue, required this.expenses, required this.profit, required this.month, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final profitColor = profit >= 0 ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_studioBg, Color(0xFF1F0A18)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _studioRose.withOpacity(0.25), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lucro líquido', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          const SizedBox(height: 2),
          Text(fmt.format(profit), style: TextStyle(color: profitColor, fontSize: 30, fontWeight: FontWeight.w700, height: 1.1)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MiniCard(label: 'Faturamento', value: fmt.format(revenue), color: _studioRose)),
              const SizedBox(width: 10),
              Expanded(child: _MiniCard(label: 'Gastos', value: fmt.format(expenses), color: AppColors.danger)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  final List<StudioEntry> allEntries;
  final StudioConfig config;
  final NumberFormat fmt;

  const _TimelineTab({required this.allEntries, required this.config, required this.fmt});

  @override
  Widget build(BuildContext context) {
    if (allEntries.isEmpty) {
      return const Center(child: Text('Nenhum histórico ainda', style: TextStyle(color: AppColors.textMuted, fontSize: 14)));
    }

    // Agrupar por mês
    final monthMap = <String, List<StudioEntry>>{};
    for (final e in allEntries) {
      final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      monthMap.putIfAbsent(key, () => []).add(e);
    }
    final months = monthMap.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: months.length,
      itemBuilder: (_, i) {
        final key = months[i];
        final entries = monthMap[key]!;
        final parts = key.split('-');
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        final rev = entries.where((e) => e.isRevenue).fold(0.0, (s, e) => s + e.amount);
        final exp = entries.where((e) => e.isExpense).fold(0.0, (s, e) => s + e.amount);
        final prolabore = (rev * config.availablePercent - exp).clamp(0.0, double.infinity);
        final profit = rev - exp;
        final profitColor = profit >= 0 ? AppColors.success : AppColors.danger;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    DateFormat('MMMM yyyy', 'pt_BR').format(dt).toUpperCase(),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: profitColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(fmt.format(profit), style: TextStyle(color: profitColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _TimelineStat(label: 'Faturamento', value: fmt.format(rev), color: _studioRose),
                  const SizedBox(width: 8),
                  _TimelineStat(label: 'Gastos', value: fmt.format(exp), color: AppColors.danger),
                  const SizedBox(width: 8),
                  _TimelineStat(label: 'Pró-labore', value: fmt.format(prolabore), color: const Color(0xFF6C5CE7)),
                ],
              ),
              const SizedBox(height: 10),
              // Barra de distribuição
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: rev > 0
                      ? Row(children: [
                          Flexible(flex: (config.safetyPercent * 100).round(), child: Container(color: const Color(0xFF4CAF50))),
                          Flexible(flex: (config.savingsPercent * 100).round(), child: Container(color: const Color(0xFF9C27B0))),
                          Flexible(flex: ((exp / rev) * 100).clamp(0, 75).round(), child: Container(color: AppColors.danger.withOpacity(0.6))),
                          Flexible(flex: ((prolabore / rev) * 100).clamp(0, 75).round(), child: Container(color: const Color(0xFF6C5CE7))),
                        ])
                      : Container(color: AppColors.surfaceLight),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TimelineStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
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

class _StudioCofrinhoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int percent;
  final Color color;

  const _StudioCofrinhoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$percent%', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color.withOpacity(0.65), fontSize: 9, height: 1.3)),
        ],
      ),
    );
  }
}

// ── Widgets de semana/mês ────────────────────────────────────────────────────

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
    final total = safety + maintenance;
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
              _BannerChip(label: labels[0], value: fmt.format(safety), color: const Color(0xFF4CAF50)),
              const SizedBox(width: 6),
              _BannerChip(label: labels[1], value: fmt.format(maintenance), color: const Color(0xFF9C27B0)),
              const SizedBox(width: 6),
              _BannerChip(label: labels[2], value: fmt.format(fuel), color: color),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('A depositar (seg. + poupança)', style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
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

class _StudioSplitRow extends StatelessWidget {
  final String label;
  final double percent;
  final double value;
  final Color color;
  final NumberFormat fmt;
  final bool bold;

  const _StudioSplitRow({
    required this.label,
    required this.percent,
    required this.value,
    required this.color,
    required this.fmt,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          '${(percent * 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
  final IconData icon;
  final Color color;
  final double value;
  final ValueChanged<double> onChanged;

  const _PercentSlider({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.onChanged,
  });

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
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text('${(value * 100).round()}%', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0.0,
          max: 0.5,
          divisions: 50,
          activeColor: color,
          inactiveColor: color.withOpacity(0.2),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── Aba de despesas fixas do Studio ─────────────────────────────────────────

class _StudioFixedTab extends ConsumerWidget {
  const _StudioFixedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fixedExpenseProvider);
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final expenses = state.expenses.where((e) => e.scope == 'studio').toList();
    final total = expenses.where((e) => e.isActive).fold(0.0, (s, e) => s + e.amount);

    return Column(
      children: [
        // Botão adicionar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: GestureDetector(
            onTap: () => _showAddSheet(context, ref),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _studioRose.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _studioRose.withOpacity(0.3), width: 0.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: _studioRose, size: 18),
                  SizedBox(width: 8),
                  Text('Nova despesa fixa do studio', style: TextStyle(color: _studioRose, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),

        // Totalizador
        if (expenses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withOpacity(0.2), width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total fixo mensal', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  Text(fmt.format(total), style: const TextStyle(color: AppColors.danger, fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),

        if (expenses.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat_rounded, color: AppColors.textMuted, size: 44),
                  SizedBox(height: 12),
                  Text('Nenhuma despesa fixa do studio', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  SizedBox(height: 4),
                  Text('Aluguel, energia, produtos fixos...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: expenses.map((e) => _StudioFixedTile(expense: e, fmt: fmt, ref: ref)).toList(),
            ),
          ),
      ],
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = _expenseCategories.first;
    int dueDay = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: _studioRose.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.repeat_rounded, color: _studioRose, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Nova despesa fixa — Studio', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Descrição', hintText: 'ex: Aluguel sala, Energia, Produto mensal'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Valor mensal (R\$)', hintText: '0,00'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              // Categoria
              const Text('Categoria', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _expenseCategories.map((cat) {
                  final sel = category == cat;
                  return GestureDetector(
                    onTap: () => setState(() => category = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? _studioRose.withOpacity(0.15) : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? _studioRose.withOpacity(0.5) : AppColors.surfaceBorder),
                      ),
                      child: Text(cat, style: TextStyle(color: sel ? _studioRose : AppColors.textSecondary, fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Dia do vencimento
              Row(
                children: [
                  const Text('Vence todo dia', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(hintText: 'ex: 5', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => dueDay = int.tryParse(v) ?? 1,
                    ),
                  ),
                  const Text(' de cada mês', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final amount = parseMoney(amountCtrl.text);
                  if (descCtrl.text.isEmpty || amount == null || amount <= 0) return;
                  ref.read(fixedExpenseProvider.notifier).add(FixedExpense(
                    id: const Uuid().v4(),
                    description: descCtrl.text.trim(),
                    amount: amount,
                    category: category,
                    scope: 'studio',
                    dueDay: dueDay.clamp(1, 28),
                  ));
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: _studioRose,
                ),
                child: const Text('Salvar despesa fixa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioFixedTile extends StatelessWidget {
  final FixedExpense expense;
  final NumberFormat fmt;
  final WidgetRef ref;

  const _StudioFixedTile({required this.expense, required this.fmt, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expense.isActive ? _studioRose.withOpacity(0.25) : AppColors.surfaceBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Toggle ativo
          GestureDetector(
            onTap: () => ref.read(fixedExpenseProvider.notifier).toggle(expense.id),
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: expense.isActive ? _studioRose.withOpacity(0.2) : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: expense.isActive ? _studioRose : AppColors.surfaceBorder),
              ),
              child: expense.isActive
                  ? const Icon(Icons.check_rounded, size: 14, color: _studioRose)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: TextStyle(
                    color: expense.isActive ? AppColors.textPrimary : AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: expense.isActive ? null : TextDecoration.lineThrough,
                  ),
                ),
                Row(
                  children: [
                    if (expense.category.isNotEmpty)
                      Text(expense.category, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    if (expense.category.isNotEmpty && expense.dueDay > 0)
                      const Text(' · ', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    if (expense.dueDay > 0)
                      Text('Vence dia ${expense.dueDay}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Text(
            fmt.format(expense.amount),
            style: TextStyle(
              color: expense.isActive ? AppColors.danger : AppColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ref.read(fixedExpenseProvider.notifier).delete(expense.id),
            child: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted, size: 18),
          ),
        ],
      ),
    );
  }
}

class _EntryList extends ConsumerWidget {
  final List<StudioEntry> entries;
  final NumberFormat fmt;

  const _EntryList({required this.entries, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('Nenhum lançamento ainda', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final entry = entries[i];
        final isRevenue = entry.isRevenue;
        final color = isRevenue ? _studioRose : AppColors.danger;

        return Dismissible(
          key: Key(entry.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
          ),
          onDismissed: (_) => ref.read(studioProvider.notifier).deleteEntry(entry.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isRevenue ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: color, size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.description, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy').format(entry.date),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                          if (entry.category != null) ...[
                            const Text(' · ', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            Text(entry.category!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isRevenue ? '+' : '-'}${fmt.format(entry.amount)}',
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
