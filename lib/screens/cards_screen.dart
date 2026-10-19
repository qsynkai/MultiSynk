import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../providers/payment_card_provider.dart';
import '../providers/finance_provider.dart';
import '../models/payment_card.dart';
import '../models/transaction.dart';
import '../logic/money.dart';

class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardState = ref.watch(paymentCardProvider);
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
                  const Text('Cartões', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                  GestureDetector(
                    onTap: () => _showAddCardSheet(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('Novo cartão', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: cardState.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : cardState.cards.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.credit_card_outlined, color: AppColors.textMuted, size: 52),
                              SizedBox(height: 12),
                              Text('Nenhum cartão cadastrado', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                              SizedBox(height: 4),
                              Text('Toque em + Novo cartão para adicionar', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          itemCount: cardState.cards.length,
                          itemBuilder: (context, i) {
                            final card = cardState.cards[i];
                            final total = cardCycleTotal(card, finance.transactions);
                            final color = _hexColor(card.color);
                            return _CardTile(
                              card: card,
                              cycleTotal: total,
                              color: color,
                              fmt: fmt,
                              onEdit: () => _showEditCardSheet(context, ref, card),
                              onDelete: () => ref.read(paymentCardProvider.notifier).delete(card.id),
                              onAdjust: () => _showAdjustBillSheet(context, ref, card, total),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCardSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final lastFourCtrl = TextEditingController();
    int closingDay = 1;
    int dueDay = 10;
    String selectedColor = '#7C3AED';

    final colors = [
      '#7C3AED', '#2563EB', '#DC2626', '#059669',
      '#D97706', '#DB2777', '#0891B2', '#65A30D',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Novo cartão', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Nome do cartão', hintText: 'ex: Nubank, Itaú'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastFourCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Últimos 4 dígitos (opcional)', hintText: '0000'),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _DaySelector(
                        label: 'Dia de fechamento',
                        value: closingDay,
                        onChanged: (v) => setS(() => closingDay = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DaySelector(
                        label: 'Dia de vencimento',
                        value: dueDay,
                        onChanged: (v) => setS(() => dueDay = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Cor', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: colors.map((c) {
                    final isSelected = c == selectedColor;
                    return GestureDetector(
                      onTap: () => setS(() => selectedColor = c),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: _hexColor(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isEmpty) return;
                    ref.read(paymentCardProvider.notifier).add(PaymentCard(
                      id: const Uuid().v4(),
                      name: nameCtrl.text.trim(),
                      lastFour: lastFourCtrl.text.isEmpty ? null : lastFourCtrl.text.trim(),
                      closingDay: closingDay,
                      dueDay: dueDay,
                      color: selectedColor,
                    ));
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Salvar cartão'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditCardSheet(BuildContext context, WidgetRef ref, PaymentCard card) {
    final nameCtrl = TextEditingController(text: card.name);
    final lastFourCtrl = TextEditingController(text: card.lastFour ?? '');
    int closingDay = card.closingDay;
    int dueDay = card.dueDay;
    String selectedColor = card.color;

    final colors = [
      '#7C3AED', '#2563EB', '#DC2626', '#059669',
      '#D97706', '#DB2777', '#0891B2', '#65A30D',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Editar cartão', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Nome do cartão'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastFourCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Últimos 4 dígitos (opcional)'),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _DaySelector(
                        label: 'Dia de fechamento',
                        value: closingDay,
                        onChanged: (v) => setS(() => closingDay = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DaySelector(
                        label: 'Dia de vencimento',
                        value: dueDay,
                        onChanged: (v) => setS(() => dueDay = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Cor', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: colors.map((c) {
                    final isSelected = c == selectedColor;
                    return GestureDetector(
                      onTap: () => setS(() => selectedColor = c),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: _hexColor(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isEmpty) return;
                    ref.read(paymentCardProvider.notifier).update(PaymentCard(
                      id: card.id,
                      name: nameCtrl.text.trim(),
                      lastFour: lastFourCtrl.text.isEmpty ? null : lastFourCtrl.text.trim(),
                      closingDay: closingDay,
                      dueDay: dueDay,
                      color: selectedColor,
                    ));
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Salvar alterações'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  void _showAdjustBillSheet(BuildContext context, WidgetRef ref, PaymentCard card, double currentTotal) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final newTotalCtrl = TextEditingController(text: currentTotal.toStringAsFixed(2).replaceAll('.', ','));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Corrigir fatura — ${card.name}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Fatura atual: ${fmt.format(currentTotal)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: newTotalCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Valor correto da fatura (R\$)', hintText: '0,00'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'O app vai criar um ajuste para igualar a fatura ao valor informado.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final newTotal = parseMoney(newTotalCtrl.text);
                if (newTotal == null) return;
                final diff = newTotal - currentTotal;
                if (diff == 0) { Navigator.pop(ctx); return; }
                ref.read(financeProvider.notifier).addTransaction(Transaction(
                  id: const Uuid().v4(),
                  description: diff > 0
                      ? 'Ajuste fatura ${card.name} (+${fmt.format(diff.abs())})'
                      : 'Ajuste fatura ${card.name} (-${fmt.format(diff.abs())})',
                  amount: diff.abs(),
                  type: diff > 0 ? TransactionType.expense : TransactionType.income,
                  date: DateTime.now(),
                  paymentMethod: PaymentMethod.credit,
                  cardId: card.id,
                ));
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Corrigir fatura'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTile extends ConsumerWidget {
  final PaymentCard card;
  final double cycleTotal;
  final Color color;
  final NumberFormat fmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAdjust;

  const _CardTile({
    required this.card,
    required this.cycleTotal,
    required this.color,
    required this.fmt,
    required this.onEdit,
    required this.onDelete,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final cardState = ref.watch(paymentCardProvider);
    final isBillPaid = cardState.isBillPaid(card.id, now.year, now.month);
    final days = card.daysUntilDue;
    final daysLabel = days == 0
        ? 'Vence hoje!'
        : days == 1
            ? 'Vence amanhã'
            : 'Vence em $days dias';
    final urgentColor = days <= 3 ? AppColors.danger : days <= 7 ? AppColors.warning : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.18), color.withOpacity(0.06)],
                begin: Alignment.centerLeft,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.credit_card_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.lastFour != null ? '${card.name} •••• ${card.lastFour}' : card.name,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Fecha dia ${card.closingDay} · Vence dia ${card.dueDay}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 18),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 18),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text('Remover cartão?', style: TextStyle(color: AppColors.textPrimary)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                        TextButton(onPressed: () { Navigator.pop(ctx); onDelete(); }, child: const Text('Remover', style: TextStyle(color: AppColors.danger))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onAdjust,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Fatura atual', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            const SizedBox(width: 6),
                            Icon(Icons.edit_rounded, color: color.withOpacity(0.5), size: 13),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(fmt.format(cycleTotal), style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: urgentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: urgentColor.withOpacity(0.3)),
                  ),
                  child: Text(daysLabel, style: TextStyle(color: urgentColor, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: GestureDetector(
              onTap: () {
                if (isBillPaid) {
                  ref.read(paymentCardProvider.notifier).unmarkBillPaid(card.id, now.year, now.month);
                } else {
                  ref.read(paymentCardProvider.notifier).markBillPaid(card.id, now.year, now.month, amount: cycleTotal);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isBillPaid ? AppColors.success.withOpacity(0.12) : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isBillPaid ? AppColors.success.withOpacity(0.5) : AppColors.surfaceBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isBillPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isBillPaid ? AppColors.success : AppColors.textMuted,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isBillPaid ? 'Fatura paga' : 'Marcar fatura como paga',
                      style: TextStyle(
                        color: isBillPaid ? AppColors.success : AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: isBillPaid ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _DaySelector({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final picked = await showDialog<int>(
              context: context,
              builder: (ctx) => _DayPickerDialog(initial: value),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dia $value', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                const Icon(Icons.expand_more, color: AppColors.textMuted, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayPickerDialog extends StatefulWidget {
  final int initial;
  const _DayPickerDialog({required this.initial});

  @override
  State<_DayPickerDialog> createState() => _DayPickerDialogState();
}

class _DayPickerDialogState extends State<_DayPickerDialog> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Selecionar dia', style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      content: SizedBox(
        width: 260,
        height: 200,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: 31,
          itemBuilder: (context, i) {
            final day = i + 1;
            final isSelected = day == _selected;
            return GestureDetector(
              onTap: () => setState(() => _selected = day),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Confirmar')),
      ],
    );
  }
}

Color _hexColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return AppColors.primary;
  }
}
