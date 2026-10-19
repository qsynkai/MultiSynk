import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../providers/finance_provider.dart';
import '../providers/fixed_expense_provider.dart';
import '../providers/payment_card_provider.dart';
import '../providers/fiorino_provider.dart';
import '../providers/studio_provider.dart';
import '../models/receivable.dart';
import '../logic/budget.dart';
import '../logic/money.dart';

class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));
  void _nextMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));

  bool get _isFuture {
    final now = DateTime.now();
    return _selectedMonth.year > now.year ||
        (_selectedMonth.year == now.year && _selectedMonth.month > now.month);
  }

  bool get _isPast {
    final now = DateTime.now();
    return _selectedMonth.year < now.year ||
        (_selectedMonth.year == now.year && _selectedMonth.month < now.month);
  }

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeProvider);
    final fixedState = ref.watch(fixedExpenseProvider);
    final cardState = ref.watch(paymentCardProvider);
    final fiorino = ref.watch(fiorinoProvider);
    final studio = ref.watch(studioProvider);
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final year = _selectedMonth.year;
    final month = _selectedMonth.month;

    // Transactions for selected month
    final monthTransactions = finance.transactions
        .where((t) => t.date.year == year && t.date.month == month)
        .toList();

    // Receivables for selected month
    final monthReceivables = finance.receivables
        .where((r) => r.expectedDate.year == year && r.expectedDate.month == month)
        .toList();

    // Paid fixed expense IDs for selected month
    final paidFixedIds = fixedState.paidIds(year, month);

    // Budget calculation for selected month
    final refDate = DateTime(year, month, 15);
    final budget = computeBudget(
      now: refDate,
      transactions: finance.transactions,
      receivables: finance.receivables,
      personalFixed: fixedState.personalExpenses,
      paidFixedExpenseIds: paidFixedIds,
      fiorinoMonthAvailable: _isFuture || _isPast ? 0 : fiorino.monthAvailable,
      studioMonthProlabore: _isFuture || _isPast ? 0 : studio.monthProlabore,
    );

    final monthLabel = DateFormat('MMMM yyyy', 'pt_BR').format(_selectedMonth);
    final isCurrentMonth = !_isFuture && !_isPast;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  const Text('Planejamento', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),

            // ── Month navigator ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _prevMonth,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 20),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final now = DateTime.now();
                        setState(() => _selectedMonth = DateTime(now.year, now.month));
                      },
                      child: Column(
                        children: [
                          Text(
                            monthLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          if (isCurrentMonth)
                            const Text('Mês atual', style: TextStyle(color: AppColors.primary, fontSize: 11)),
                          if (_isFuture)
                            const Text('Planejado', style: TextStyle(color: AppColors.accent, fontSize: 11)),
                          if (_isPast)
                            const Text('Histórico', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _nextMonth,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── Summary cards ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _SummaryChip(label: 'Receita', value: fmt.format(budget.monthIncome + budget.receivablesDue), color: AppColors.success),
                  const SizedBox(width: 8),
                  _SummaryChip(label: 'Gastos', value: fmt.format(budget.monthExpenses), color: AppColors.danger),
                  const SizedBox(width: 8),
                  _SummaryChip(
                    label: 'Saldo',
                    value: fmt.format(budget.available),
                    color: budget.available >= 0 ? AppColors.primary : AppColors.danger,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Body ─────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Despesas fixas
                  _SectionHeader(
                    title: 'Despesas Fixas',
                    subtitle: '${paidFixedIds.length}/${fixedState.personalExpenses.length} pagas',
                    icon: Icons.repeat_rounded,
                    color: AppColors.warning,
                  ),
                  if (fixedState.personalExpenses.isEmpty)
                    _EmptyNote('Nenhuma despesa fixa pessoal cadastrada')
                  else
                    ...fixedState.personalExpenses.map((fe) {
                      final paid = paidFixedIds.contains(fe.id);
                      return _FixedExpenseRow(
                        title: fe.description,
                        amount: fmt.format(fe.amount),
                        dueDay: fe.dueDay,
                        isPaid: paid,
                        onToggle: () {
                          if (paid) {
                            ref.read(fixedExpenseProvider.notifier).unmarkPaid(fe.id, year, month);
                          } else {
                            ref.read(fixedExpenseProvider.notifier).markPaid(fe.id, year, month);
                          }
                        },
                      );
                    }),

                  const SizedBox(height: 20),

                  // Recebimentos
                  _SectionHeader(
                    title: 'A Receber',
                    subtitle: _isFuture ? 'Previsão' : (monthReceivables.isEmpty ? 'Nenhum' : '${monthReceivables.where((r) => r.status == ReceivableStatus.received).length}/${monthReceivables.length} recebidos'),
                    icon: Icons.trending_up_rounded,
                    color: AppColors.success,
                    actionLabel: _isFuture ? '+ Adicionar' : null,
                    onAction: _isFuture ? () => _showAddReceivable(context, year, month) : null,
                  ),
                  if (monthReceivables.isEmpty)
                    _EmptyNote(_isFuture ? 'Toque em "+ Adicionar" para planejar uma receita futura' : 'Nenhum recebimento previsto para este mês')
                  else
                    ...monthReceivables.map((r) {
                      final received = r.status == ReceivableStatus.received;
                      return _ReceivableRow(
                        title: r.description,
                        amount: fmt.format(r.expectedAmount),
                        isReceived: received,
                        onToggle: received
                            ? () => ref.read(financeProvider.notifier).unmarkReceivableReceived(r)
                            : () => _confirmMarkReceived(context, r),
                      );
                    }),

                  const SizedBox(height: 20),

                  // Faturas de cartão
                  if (cardState.cards.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Faturas de Cartão',
                      subtitle: '${cardState.cards.where((c) => cardState.isBillPaid(c.id, year, month)).length}/${cardState.cards.length} pagas',
                      icon: Icons.credit_card_rounded,
                      color: AppColors.accent,
                    ),
                    ...cardState.cards.map((card) {
                      final billPaid = cardState.isBillPaid(card.id, year, month);
                      final total = cardMonthTotal(card, finance.transactions, year, month);
                      return _CardBillRow(
                        cardName: card.name,
                        lastFour: card.lastFour,
                        amount: fmt.format(total),
                        isPaid: billPaid,
                        onToggle: total > 0
                            ? () {
                                if (billPaid) {
                                  ref.read(paymentCardProvider.notifier).unmarkBillPaid(card.id, year, month);
                                } else {
                                  ref.read(paymentCardProvider.notifier).markBillPaid(card.id, year, month, amount: total);
                                }
                              }
                            : null,
                      );
                    }),
                    const SizedBox(height: 20),
                  ],

                  // Studio fixas (se houver)
                  if (fixedState.studioExpenses.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Fixas do Studio',
                      subtitle: '${fixedState.studioExpenses.where((fe) => fixedState.isPaid(fe.id, year, month)).length}/${fixedState.studioExpenses.length} pagas',
                      icon: Icons.spa_rounded,
                      color: AppColors.primary,
                    ),
                    ...fixedState.studioExpenses.map((fe) {
                      final paid = fixedState.isPaid(fe.id, year, month);
                      return _FixedExpenseRow(
                        title: fe.description,
                        amount: fmt.format(fe.amount),
                        dueDay: fe.dueDay,
                        isPaid: paid,
                        onToggle: () {
                          if (paid) {
                            ref.read(fixedExpenseProvider.notifier).unmarkPaid(fe.id, year, month);
                          } else {
                            ref.read(fixedExpenseProvider.notifier).markPaid(fe.id, year, month);
                          }
                        },
                      );
                    }),
                    const SizedBox(height: 20),
                  ],

                  // Mini timeline dos próximos 3 meses
                  _SectionHeader(
                    title: 'Próximos Meses',
                    subtitle: 'Visão geral',
                    icon: Icons.timeline_rounded,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 6,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (ctx, i) {
                        final m = DateTime(_selectedMonth.year, _selectedMonth.month + i + 1);
                        final mBudget = computeBudget(
                          now: DateTime(m.year, m.month, 15),
                          transactions: finance.transactions,
                          receivables: finance.receivables,
                          personalFixed: fixedState.personalExpenses,
                          paidFixedExpenseIds: fixedState.paidIds(m.year, m.month),
                        );
                        final available = mBudget.available;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedMonth = m),
                          child: Container(
                            width: 120,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat('MMM yyyy', 'pt_BR').format(m),
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text(
                                  fmt.format(mBudget.monthIncome + mBudget.receivablesDue),
                                  style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '- ${fmt.format(mBudget.monthExpenses + mBudget.pendingFixed)}',
                                  style: const TextStyle(color: AppColors.danger, fontSize: 11),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (available >= 0 ? AppColors.success : AppColors.danger).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    available >= 0 ? '+${fmt.format(available)}' : fmt.format(available),
                                    style: TextStyle(
                                      color: available >= 0 ? AppColors.success : AppColors.danger,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmMarkReceived(BuildContext context, Receivable r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Confirmar recebimento', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Text(
          'Marcar "${r.description}" como recebido?\n\nUma receita de ${NumberFormat.currency(locale: "pt_BR", symbol: "R\$").format(r.expectedAmount)} será lançada automaticamente em Finanças.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(financeProvider.notifier).markReceivableReceived(r);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _showAddReceivable(BuildContext context, int year, int month) {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final initialDate = DateTime(year, month, 15);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Receita prevista — ${DateFormat('MMMM yyyy', 'pt_BR').format(DateTime(year, month))}',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final amount = parseMoney(amountCtrl.text);
                  if (descCtrl.text.isEmpty || amount == null) return;
                  ref.read(financeProvider.notifier).addReceivable(Receivable(
                    id: const Uuid().v4(),
                    description: descCtrl.text,
                    expectedAmount: amount,
                    expectedDate: initialDate,
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

// ── Widgets internos ────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
    );
  }
}

class _FixedExpenseRow extends StatelessWidget {
  final String title;
  final String amount;
  final int dueDay;
  final bool isPaid;
  final VoidCallback onToggle;

  const _FixedExpenseRow({
    required this.title,
    required this.amount,
    required this.dueDay,
    required this.isPaid,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: isPaid ? AppColors.success.withOpacity(0.15) : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isPaid ? AppColors.success : AppColors.surfaceBorder),
              ),
              child: isPaid ? const Icon(Icons.check_rounded, size: 14, color: AppColors.success) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: isPaid ? AppColors.textMuted : AppColors.textPrimary,
                        fontSize: 13,
                        decoration: isPaid ? TextDecoration.lineThrough : null)),
                if (dueDay > 0)
                  Text('Vence dia $dueDay', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
          Text(amount,
              style: TextStyle(
                  color: isPaid ? AppColors.textMuted : AppColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: isPaid ? TextDecoration.lineThrough : null)),
        ],
      ),
    );
  }
}

class _ReceivableRow extends StatelessWidget {
  final String title;
  final String amount;
  final bool isReceived;
  final VoidCallback onToggle;

  const _ReceivableRow({
    required this.title,
    required this.amount,
    required this.isReceived,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: isReceived ? AppColors.success.withOpacity(0.15) : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: isReceived ? AppColors.success : AppColors.surfaceBorder),
              ),
              child: isReceived ? const Icon(Icons.check_rounded, size: 14, color: AppColors.success) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: isReceived ? AppColors.textMuted : AppColors.textPrimary,
                    fontSize: 13,
                    decoration: isReceived ? TextDecoration.lineThrough : null)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount,
                  style: TextStyle(
                      color: isReceived ? AppColors.textMuted : AppColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(isReceived ? 'Recebido — desfazer?' : 'Tap para marcar',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardBillRow extends StatelessWidget {
  final String cardName;
  final String? lastFour;
  final String amount;
  final bool isPaid;
  final VoidCallback? onToggle;

  const _CardBillRow({
    required this.cardName,
    this.lastFour,
    required this.amount,
    required this.isPaid,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: isPaid ? AppColors.success.withOpacity(0.15) : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isPaid ? AppColors.success : (onToggle != null ? AppColors.surfaceBorder : AppColors.surfaceLight)),
              ),
              child: isPaid ? const Icon(Icons.check_rounded, size: 14, color: AppColors.success) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cardName,
                    style: TextStyle(
                        color: isPaid ? AppColors.textMuted : AppColors.textPrimary,
                        fontSize: 13)),
                if (lastFour != null)
                  Text('**** $lastFour', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
          Text(amount,
              style: TextStyle(
                  color: isPaid ? AppColors.textMuted : AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: isPaid ? TextDecoration.lineThrough : null)),
        ],
      ),
    );
  }
}
