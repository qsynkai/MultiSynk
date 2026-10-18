import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../providers/finance_provider.dart';
import '../providers/payment_card_provider.dart';
import '../models/transaction.dart';
import '../models/payment_card.dart';
import '../models/receivable.dart';
import '../models/fixed_expense.dart';
import '../providers/fixed_expense_provider.dart';
import '../widgets/payment_method_selector.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeProvider);
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Finanças', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                  GestureDetector(
                    onTap: () => _showAddSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('Novo', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Lançamentos'),
                  Tab(text: 'A receber'),
                  Tab(text: 'Fixas'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _TransactionsTab(finance: finance, fmt: fmt),
                  _ReceivablesTab(finance: finance, fmt: fmt),
                  const _FixedExpensesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    bool isExpense = true;
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    PaymentMethod? paymentMethod;
    PaymentCard? selectedCard;
    int installments = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final cards = ref.read(paymentCardProvider).cards;
        return StatefulBuilder(
          builder: (ctx, setState) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Novo lançamento', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isExpense = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isExpense ? AppColors.danger.withOpacity(0.15) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isExpense ? AppColors.danger : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.remove_circle_outline, color: isExpense ? AppColors.danger : AppColors.textMuted, size: 16),
                              const SizedBox(width: 6),
                              Text('Despesa', style: TextStyle(color: isExpense ? AppColors.danger : AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() { isExpense = false; paymentMethod = null; selectedCard = null; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isExpense ? AppColors.success.withOpacity(0.15) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: !isExpense ? AppColors.success : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline, color: !isExpense ? AppColors.success : AppColors.textMuted, size: 16),
                              const SizedBox(width: 6),
                              Text('Receita', style: TextStyle(color: !isExpense ? AppColors.success : AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Valor (R\$)', hintText: '0,00'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                if (isExpense) ...[
                  const SizedBox(height: 16),
                  PaymentMethodSelector(
                    selectedMethod: paymentMethod,
                    selectedCard: selectedCard,
                    cards: cards,
                    installments: installments,
                    onMethodChanged: (m) => setState(() { paymentMethod = m; if (m != PaymentMethod.credit) selectedCard = null; }),
                    onCardChanged: (c) => setState(() => selectedCard = c),
                    onInstallmentsChanged: (v) => setState(() => installments = v),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                    if (descCtrl.text.isEmpty || amount == null) return;
                    final groupId = installments > 1 ? const Uuid().v4() : null;
                    final perInstall = installments > 1 ? amount / installments : amount;
                    final now = DateTime.now();
                    for (int i = 0; i < installments; i++) {
                      final date = DateTime(now.year, now.month + i, now.day);
                      final desc = installments > 1
                          ? '${descCtrl.text} (${i + 1}/$installments)'
                          : descCtrl.text;
                      ref.read(financeProvider.notifier).addTransaction(Transaction(
                        id: const Uuid().v4(),
                        description: desc,
                        amount: perInstall,
                        type: isExpense ? TransactionType.expense : TransactionType.income,
                        date: date,
                        paymentMethod: paymentMethod,
                        cardId: selectedCard?.id,
                        installments: installments,
                        installmentNumber: i + 1,
                        installmentGroupId: groupId,
                      ));
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(installments > 1 ? 'Salvar ($installments parcelas)' : 'Salvar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  final FinanceState finance;
  final NumberFormat fmt;

  const _TransactionsTab({required this.finance, required this.fmt});

  @override
  Widget build(BuildContext context) {
    if (finance.transactions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 48),
            SizedBox(height: 12),
            Text('Nenhum lançamento ainda', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            SizedBox(height: 4),
            Text('Toque em + Novo para começar', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: finance.transactions.length,
      itemBuilder: (context, i) {
        final t = finance.transactions[i];
        final isIncome = t.type == TransactionType.income;
        return Container(
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
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: (isIncome ? AppColors.success : AppColors.danger).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: isIncome ? AppColors.success : AppColors.danger,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.description, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                    Text(DateFormat('dd/MM/yyyy').format(t.date), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : '-'} ${fmt.format(t.amount)}',
                style: TextStyle(color: isIncome ? AppColors.success : AppColors.danger, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FixedExpensesTab extends ConsumerWidget {
  const _FixedExpensesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fixedExpenseProvider);
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final personal = state.expenses.where((e) => e.scope == 'personal').toList();
    final studio   = state.expenses.where((e) => e.scope == 'studio').toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: GestureDetector(
            onTap: () => _showAddSheet(context, ref),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 0.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text('Nova despesa fixa', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
        if (state.expenses.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat_rounded, color: AppColors.textMuted, size: 48),
                  SizedBox(height: 12),
                  Text('Nenhuma despesa fixa ainda', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  SizedBox(height: 4),
                  Text('Aluguel, internet, contas mensais...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (personal.isNotEmpty) ...[
                  _SectionLabel(label: 'Casa / Pessoal', total: personal.where((e) => e.isActive).fold(0.0, (s, e) => s + e.amount), fmt: fmt),
                  ...personal.map((e) => _FixedTile(expense: e, fmt: fmt, ref: ref)),
                  const SizedBox(height: 16),
                ],
                if (studio.isNotEmpty) ...[
                  _SectionLabel(label: 'Studio', total: studio.where((e) => e.isActive).fold(0.0, (s, e) => s + e.amount), fmt: fmt),
                  ...studio.map((e) => _FixedTile(expense: e, fmt: fmt, ref: ref)),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
      ],
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String scope = 'personal';
    int dueDay = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nova despesa fixa', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Descrição', hintText: 'ex: Aluguel, Internet, Energia'),
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
              const Text('Categoria', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => scope = 'personal'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: scope == 'personal' ? AppColors.primary.withOpacity(0.15) : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: scope == 'personal' ? AppColors.primary : Colors.transparent),
                        ),
                        child: Text('Casa / Pessoal', textAlign: TextAlign.center,
                            style: TextStyle(color: scope == 'personal' ? AppColors.primary : AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => scope = 'studio'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: scope == 'studio' ? AppColors.accent.withOpacity(0.15) : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: scope == 'studio' ? AppColors.accent : Colors.transparent),
                        ),
                        child: Text('Studio', textAlign: TextAlign.center,
                            style: TextStyle(color: scope == 'studio' ? AppColors.accent : AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                  final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                  if (descCtrl.text.isEmpty || amount == null) return;
                  ref.read(fixedExpenseProvider.notifier).add(FixedExpense(
                    id: const Uuid().v4(),
                    description: descCtrl.text,
                    amount: amount,
                    scope: scope,
                    dueDay: dueDay.clamp(1, 28),
                  ));
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final double total;
  final NumberFormat fmt;
  const _SectionLabel({required this.label, required this.total, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          Text(fmt.format(total), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FixedTile extends StatelessWidget {
  final FixedExpense expense;
  final NumberFormat fmt;
  final WidgetRef ref;
  const _FixedTile({required this.expense, required this.fmt, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ref.read(fixedExpenseProvider.notifier).toggle(expense.id),
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: expense.isActive ? AppColors.primary.withOpacity(0.2) : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: expense.isActive ? AppColors.primary : AppColors.surfaceBorder),
              ),
              child: expense.isActive
                  ? const Icon(Icons.check_rounded, size: 14, color: AppColors.primary)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.description,
                    style: TextStyle(
                        color: expense.isActive ? AppColors.textPrimary : AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: expense.isActive ? null : TextDecoration.lineThrough)),
                if (expense.dueDay > 0)
                  Text('Vence dia ${expense.dueDay}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Text(fmt.format(expense.amount),
              style: TextStyle(
                  color: expense.isActive ? AppColors.danger : AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
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

class _ReceivablesTab extends ConsumerWidget {
  final FinanceState finance;
  final NumberFormat fmt;

  const _ReceivablesTab({required this.finance, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: GestureDetector(
            onTap: () => _showAddReceivable(context, ref),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3), width: 0.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: AppColors.success, size: 18),
                  SizedBox(width: 8),
                  Text('Adicionar recebimento futuro', style: TextStyle(color: AppColors.success, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: finance.receivables.isEmpty
              ? const Center(
                  child: Text('Nenhum recebimento cadastrado', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: finance.receivables.length,
                  itemBuilder: (context, i) {
                    final r = finance.receivables[i];
                    final received = r.status == ReceivableStatus.received;
                    return Container(
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
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: (received ? AppColors.textMuted : AppColors.success).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              received ? Icons.check_rounded : Icons.schedule_rounded,
                              color: received ? AppColors.textMuted : AppColors.success,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.description,
                                    style: TextStyle(
                                        color: received ? AppColors.textMuted : AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        decoration: received ? TextDecoration.lineThrough : null)),
                                Text(DateFormat('dd/MM/yyyy').format(r.expectedDate), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(fmt.format(r.amountToReceive),
                                  style: TextStyle(color: received ? AppColors.textMuted : AppColors.success, fontSize: 14, fontWeight: FontWeight.w600)),
                              if (!received)
                                GestureDetector(
                                  onTap: () => ref.read(financeProvider.notifier).markReceivableReceived(r),
                                  child: const Text('Recebido', style: TextStyle(color: AppColors.accent, fontSize: 11)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddReceivable(BuildContext context, WidgetRef ref) {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recebimento futuro', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Descrição', hintText: 'ex: Salário, Freela, Aluguel'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Valor esperado (R\$)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (ctx, child) => Theme(
                      data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.primary)),
                      child: child!,
                    ),
                  );
                  if (date != null) setState(() => selectedDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Previsto: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                  if (descCtrl.text.isEmpty || amount == null) return;
                  ref.read(financeProvider.notifier).addReceivable(Receivable(
                    id: const Uuid().v4(),
                    description: descCtrl.text,
                    expectedAmount: amount,
                    expectedDate: selectedDate,
                  ));
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
