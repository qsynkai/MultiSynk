import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../providers/finance_provider.dart';
import '../providers/task_provider.dart';
import '../providers/fiorino_provider.dart';
import '../providers/studio_provider.dart';
import '../providers/fixed_expense_provider.dart';
import '../providers/payment_card_provider.dart';
import '../models/task.dart';
import '../models/receivable.dart';
import '../models/transaction.dart';
import '../models/payment_card.dart';
import '../services/ai_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import 'auth_screen.dart';
import 'fiorino_screen.dart';
import 'studio_screen.dart';
import 'cards_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkMonthChange());
  }

  Future<void> _handleCloudSync() async {
    if (!SupabaseService.isSignedIn) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      if (result == true) setState(() {});
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sincronizando dados...')),
    );
    await SyncService.syncAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados sincronizados!')),
      );
    }
  }

  Future<void> _checkMonthChange() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentKey = '${now.year}-${now.month}';
    final lastKey = prefs.getString('last_opened_month') ?? '';

    if (lastKey.isNotEmpty && lastKey != currentKey && mounted) {
      final parts = lastKey.split('-');
      final lastMonth = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      _showMonthChangeDialog(lastMonth);
    }
    await prefs.setString('last_opened_month', currentKey);
  }

  void _showMonthChangeDialog(DateTime lastMonth) {
    final fixedExpenses = ref.read(fixedExpenseProvider);
    final hasFixed = fixedExpenses.expenses.isNotEmpty;
    final monthName = DateFormat('MMMM', 'pt_BR').format(DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 12),
            Text('Novo mês chegou!', style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Bem-vindo a $monthName! Hora de atualizar os lançamentos do mês.${hasFixed ? '\n\nVocê tem despesas fixas cadastradas. Deseja aplicá-las agora?' : ''}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Lembrar depois', style: TextStyle(color: AppColors.textMuted)),
          ),
          if (hasFixed)
            ElevatedButton(
              onPressed: () {
                _applyFixedExpenses();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Aplicar despesas fixas'),
            )
          else
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Vamos lá!'),
            ),
        ],
      ),
    );
  }

  Future<void> _applyFixedExpenses() async {
    final fixedExpenses = ref.read(fixedExpenseProvider);
    final now = DateTime.now();

    for (final fe in fixedExpenses.studioExpenses) {
      await ref.read(studioProvider.notifier).addEntry(
        amount: fe.amount,
        type: 'expense',
        description: fe.description,
        category: fe.category.isEmpty ? null : fe.category,
        date: DateTime(now.year, now.month, 1),
        notes: 'Despesa fixa aplicada automaticamente',
      );
    }

    for (final fe in fixedExpenses.personalExpenses) {
      await ref.read(financeProvider.notifier).addTransaction(Transaction(
        id: 'fe-${fe.id}-${now.year}-${now.month}',
        description: fe.description,
        amount: fe.amount,
        type: TransactionType.expense,
        category: fe.category.isEmpty ? null : fe.category,
        date: DateTime(now.year, now.month, 1),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeProvider);
    final tasks = ref.watch(taskProvider);
    final fiorino = ref.watch(fiorinoProvider);
    final studio = ref.watch(studioProvider);
    final fixedState = ref.watch(fixedExpenseProvider);
    final cardState = ref.watch(paymentCardProvider);
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    // Renda mensal combinada: Finance (pessoal) + Fiorino disponível + Prolabore studio
    final combinedMonthIncome = finance.monthIncome
        + fiorino.monthAvailable
        + studio.monthProlabore;
    final combinedMonthExpenses = finance.monthExpenses;

    // Despesas fixas ainda não lançadas como transação este mês
    final now = DateTime.now();
    final appliedFixedIds = finance.transactions
        .where((t) => t.id.startsWith('fe-'))
        .map((t) => t.id)
        .toSet();
    final pendingFixed = fixedState.personalExpenses
        .where((fe) => !appliedFixedIds.contains('fe-${fe.id}-${now.year}-${now.month}'))
        .fold(0.0, (sum, fe) => sum + fe.amount);

    final combinedAvailable = combinedMonthIncome + finance.pendingReceivables - combinedMonthExpenses - pendingFixed;
    final wl = finance.weeksUntilMonthEnd;
    final combinedWeeklyBudget = (combinedAvailable / wl) - finance.weekExpenses;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Image.asset(
                            'assets/images/multisynk_logo.png',
                            height: 28,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showAiAnalysis(
                        context,
                        monthIncome: combinedMonthIncome,
                        fiorinoMonthAvailable: fiorino.monthAvailable,
                        studioMonthProlabore: studio.monthProlabore,
                        monthExpenses: combinedMonthExpenses,
                        weekExpenses: finance.weekExpenses,
                        pendingReceivables: finance.pendingReceivables,
                        pendingFixed: pendingFixed,
                        weeklyBudget: combinedWeeklyBudget,
                        weeksUntilMonthEnd: wl,
                        fixedState: fixedState,
                        appliedFixedIds: appliedFixedIds,
                        cardTotal: cardState.cards.fold(0.0, (s, c) => s + cardCycleTotal(c, finance.transactions)),
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 0.5),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _handleCloudSync,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
                        ),
                        child: Icon(
                          SupabaseService.isSignedIn
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                          color: SupabaseService.isSignedIn
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
                      ),
                      child: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary, size: 20),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _WeeklyBudgetCard(
                  budget: combinedWeeklyBudget,
                  income: combinedMonthIncome,
                  expenses: combinedMonthExpenses,
                  receivables: finance.pendingReceivables,
                  pendingFixed: pendingFixed,
                  fmt: fmt,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickStatCard(
                        label: 'A receber',
                        value: fmt.format(finance.pendingReceivables),
                        color: AppColors.success,
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickStatCard(
                        label: 'Gastos mês',
                        value: fmt.format(combinedMonthExpenses),
                        color: AppColors.danger,
                        icon: Icons.trending_down_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Banner Fiorino — entrada do dia
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FiorinoScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF0D1F0D), Color(0xFF162616)]),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: fiorino.todayEntry != null
                            ? AppColors.success.withOpacity(0.4)
                            : AppColors.success.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            fiorino.todayEntry != null ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                            color: AppColors.success,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fiorino.todayEntry != null ? 'Fiorino — entrada registrada' : 'Fiorino — registrar entrada do dia',
                                style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                fiorino.todayEntry != null
                                    ? NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(fiorino.todayEntry!.amount)
                                    : 'Toque para lançar e ver seus cofrinhos',
                                style: TextStyle(color: AppColors.success.withOpacity(0.65), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: AppColors.success.withOpacity(0.45), size: 13),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Banner Ferretti Studio Beauty
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudioScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1A0D14), Color(0xFF1F0A18)]),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: studio.hasTodayRevenue
                            ? const Color(0xFFD4548A).withOpacity(0.45)
                            : const Color(0xFFD4548A).withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4548A).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            studio.hasTodayRevenue ? Icons.spa_rounded : Icons.spa_outlined,
                            color: const Color(0xFFD4548A),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ferretti Studio Beauty', style: TextStyle(color: Color(0xFFD4548A), fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(
                                studio.monthRevenue > 0
                                    ? 'Pró-labore: ${fmt.format(studio.monthProlabore)} · Fat: ${fmt.format(studio.monthRevenue)}'
                                    : 'Registrar faturamento ou gastos do estúdio',
                                style: TextStyle(color: const Color(0xFFD4548A).withOpacity(0.65), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: const Color(0xFFD4548A).withOpacity(0.45), size: 13),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Faturas de cartão
            if (cardState.cards.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: _FaturasCard(cards: cardState.cards, transactions: finance.transactions, fmt: fmt),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Prioridades de hoje',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (tasks.isAnalyzing)
                      const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                  ],
                ),
              ),
            ),

            if (tasks.pendingTasks.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.check_circle_outline, color: AppColors.success, size: 36),
                        SizedBox(height: 8),
                        Text('Nenhuma tarefa pendente', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final task = tasks.pendingTasks.take(3).toList()[i];
                    return Padding(
                      padding: EdgeInsets.fromLTRB(20, i == 0 ? 12 : 8, 20, 0),
                      child: _TaskPreviewTile(task: task),
                    );
                  },
                  childCount: tasks.pendingTasks.take(3).length,
                ),
              ),


            // Contas a pagar — contagem regressiva
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: const Text(
                  'Contas a pagar',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _BillsCountdown(receivables: finance.receivables, fmt: fmt),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  void _showAiAnalysis(
    BuildContext context, {
    required double monthIncome,
    required double fiorinoMonthAvailable,
    required double studioMonthProlabore,
    required double monthExpenses,
    required double weekExpenses,
    required double pendingReceivables,
    required double pendingFixed,
    required double weeklyBudget,
    required int weeksUntilMonthEnd,
    required FixedExpenseState fixedState,
    required Set<String> appliedFixedIds,
    required double cardTotal,
  }) {
    final now = DateTime.now();
    final activeFixed = fixedState.personalExpenses.map((fe) => {
      'name': fe.description,
      'amount': fe.amount,
      'due_day': fe.dueDay,
      'scope': fe.scope,
      'applied': appliedFixedIds.contains('fe-${fe.id}-${now.year}-${now.month}'),
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiAnalysisSheet(
        monthIncome: monthIncome,
        fiorinoMonthAvailable: fiorinoMonthAvailable,
        studioMonthProlabore: studioMonthProlabore,
        monthExpenses: monthExpenses,
        weekExpenses: weekExpenses,
        pendingReceivables: pendingReceivables,
        pendingFixed: pendingFixed,
        weeklyBudget: weeklyBudget,
        weeksUntilMonthEnd: weeksUntilMonthEnd,
        activeFixed: activeFixed,
        cardTotal: cardTotal,
      ),
    );
  }
}

class _FaturasCard extends StatelessWidget {
  final List<PaymentCard> cards;
  final List<Transaction> transactions;
  final NumberFormat fmt;

  const _FaturasCard({required this.cards, required this.transactions, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final totalFatura = cards.fold(0.0, (sum, c) => sum + cardCycleTotal(c, transactions));
    final urgentCards = cards.where((c) => c.daysUntilDue <= 7).toList()
      ..sort((a, b) => a.daysUntilDue.compareTo(b.daysUntilDue));

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CardsScreen())),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0D0D1F), Color(0xFF14143A)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: urgentCards.isNotEmpty
                ? AppColors.warning.withOpacity(0.4)
                : AppColors.primary.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.credit_card_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Faturas dos cartões', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    urgentCards.isNotEmpty
                        ? '${urgentCards.first.name} vence em ${urgentCards.first.daysUntilDue} dias · Total: ${fmt.format(totalFatura)}'
                        : 'Total este ciclo: ${fmt.format(totalFatura)}',
                    style: TextStyle(color: AppColors.primary.withOpacity(0.65), fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary.withOpacity(0.45), size: 13),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBudgetCard extends StatelessWidget {
  final double budget;
  final double income;
  final double expenses;
  final double receivables;
  final double pendingFixed;
  final NumberFormat fmt;

  const _WeeklyBudgetCard({
    required this.budget,
    required this.income,
    required this.expenses,
    required this.receivables,
    required this.pendingFixed,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = budget >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPositive
              ? [const Color(0xFF1A1A35), const Color(0xFF2D1B69)]
              : [const Color(0xFF2D1515), const Color(0xFF1A0808)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPositive ? AppColors.primary.withOpacity(0.3) : AppColors.danger.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, color: Colors.white.withOpacity(0.7), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'ESTA SEMANA',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Posso gastar',
            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            fmt.format(budget.abs()),
            style: TextStyle(
              color: isPositive ? Colors.white : AppColors.danger,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          if (!isPositive)
            Text(
              'Atenção: orçamento negativo',
              style: TextStyle(color: AppColors.danger.withOpacity(0.8), fontSize: 12),
            ),
          if (pendingFixed > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withOpacity(0.25), width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${fmt.format(pendingFixed)} em fixas pendentes já deduzidas',
                      style: TextStyle(color: AppColors.warning.withOpacity(0.9), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _BudgetStat(
                    label: 'Receita mês',
                    value: fmt.format(income),
                    color: AppColors.success,
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
                Container(width: 0.5, height: 32, color: Colors.white.withOpacity(0.15)),
                Expanded(
                  child: _BudgetStat(
                    label: 'A receber',
                    value: fmt.format(receivables),
                    color: AppColors.accent,
                    icon: Icons.schedule_rounded,
                  ),
                ),
                Container(width: 0.5, height: 32, color: Colors.white.withOpacity(0.15)),
                Expanded(
                  child: _BudgetStat(
                    label: 'Gastos',
                    value: fmt.format(expenses),
                    color: AppColors.danger,
                    icon: Icons.remove_circle_outline_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _BudgetStat({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _QuickStatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskPreviewTile extends StatelessWidget {
  final Task task;

  const _TaskPreviewTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (task.effectivePriority) {
      TaskPriority.urgent => AppColors.danger,
      TaskPriority.high => AppColors.warning,
      TaskPriority.medium => AppColors.primary,
      _ => AppColors.textMuted,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 40,
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                if (task.aiReason != null)
                  Text(task.aiReason!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (task.effectivePriority == TaskPriority.urgent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Urgente', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _BillsCountdown extends StatelessWidget {
  final List<Receivable> receivables;
  final NumberFormat fmt;

  const _BillsCountdown({required this.receivables, required this.fmt});

  @override
  Widget build(BuildContext context) {
    // Show pending receivables (bills to pay) sorted by due date
    final bills = receivables
        .where((r) => r.status != ReceivableStatus.received)
        .toList()
      ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));

    if (bills.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 20),
            SizedBox(width: 10),
            Text('Nenhuma conta pendente', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return Column(
      children: bills.take(4).map((bill) {
        final today = DateTime.now();
        final daysLeft = bill.expectedDate.difference(DateTime(today.year, today.month, today.day)).inDays;
        final isOverdue = daysLeft < 0;
        final isToday = daysLeft == 0;
        final isSoon = daysLeft > 0 && daysLeft <= 3;

        final Color statusColor;
        final String daysLabel;
        final IconData icon;

        if (isOverdue) {
          statusColor = AppColors.danger;
          daysLabel = '${daysLeft.abs()}d atrasada';
          icon = Icons.warning_amber_rounded;
        } else if (isToday) {
          statusColor = AppColors.warning;
          daysLabel = 'Vence hoje';
          icon = Icons.today_rounded;
        } else if (isSoon) {
          statusColor = AppColors.warning;
          daysLabel = 'em $daysLeft dia${daysLeft == 1 ? '' : 's'}';
          icon = Icons.schedule_rounded;
        } else {
          statusColor = AppColors.textSecondary;
          daysLabel = 'em $daysLeft dias';
          icon = Icons.event_rounded;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isOverdue || isToday || isSoon) ? statusColor.withOpacity(0.35) : AppColors.surfaceBorder,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: statusColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bill.description, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                    Text(
                      DateFormat('dd/MM/yyyy').format(bill.expectedDate),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmt.format(bill.amountToReceive), style: TextStyle(color: statusColor, fontSize: 14, fontWeight: FontWeight.w700)),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(daysLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AiAnalysisSheet extends StatefulWidget {
  final double monthIncome;
  final double fiorinoMonthAvailable;
  final double studioMonthProlabore;
  final double monthExpenses;
  final double weekExpenses;
  final double pendingReceivables;
  final double pendingFixed;
  final double weeklyBudget;
  final int weeksUntilMonthEnd;
  final List<Map<String, dynamic>> activeFixed;
  final double cardTotal;

  const _AiAnalysisSheet({
    required this.monthIncome,
    required this.fiorinoMonthAvailable,
    required this.studioMonthProlabore,
    required this.monthExpenses,
    required this.weekExpenses,
    required this.pendingReceivables,
    required this.pendingFixed,
    required this.weeklyBudget,
    required this.weeksUntilMonthEnd,
    required this.activeFixed,
    required this.cardTotal,
  });

  @override
  State<_AiAnalysisSheet> createState() => _AiAnalysisSheetState();
}

class _AiAnalysisSheetState extends State<_AiAnalysisSheet> {
  String? _analysis;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() { _loading = true; _analysis = null; });
    final result = await AiService.analyzeFinancialContext(
      monthIncome: widget.monthIncome,
      fiorinoMonthAvailable: widget.fiorinoMonthAvailable,
      studioMonthProlabore: widget.studioMonthProlabore,
      monthExpenses: widget.monthExpenses,
      weekExpenses: widget.weekExpenses,
      pendingReceivables: widget.pendingReceivables,
      pendingFixed: widget.pendingFixed,
      weeklyBudget: widget.weeklyBudget,
      weeksUntilMonthEnd: widget.weeksUntilMonthEnd,
      activeFixed: widget.activeFixed,
      cardTotal: widget.cardTotal,
    );
    if (mounted) setState(() { _analysis = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Color(0xFF12111A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Análise IA', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('Resumo do seu planejamento', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                if (!_loading)
                  GestureDetector(
                    onTap: _analyze,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.refresh_rounded, color: AppColors.primary, size: 14),
                          SizedBox(width: 4),
                          Text('Atualizar', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 0.5, color: Colors.white.withOpacity(0.08)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: _loading
                  ? Column(
                      children: [
                        const SizedBox(height: 40),
                        const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                        const SizedBox(height: 16),
                        Text(
                          'Analisando sua situação financeira...',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(height: 40),
                      ],
                    )
                  : Text(
                      _analysis ?? '',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.65,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
