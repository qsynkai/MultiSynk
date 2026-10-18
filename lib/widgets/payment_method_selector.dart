import 'package:flutter/material.dart';
import '../models/transaction.dart' show PaymentMethod;
import '../models/payment_card.dart';
import '../theme/app_theme.dart';

class PaymentMethodSelector extends StatelessWidget {
  final PaymentMethod? selectedMethod;
  final PaymentCard? selectedCard;
  final List<PaymentCard> cards;
  final int installments;
  final ValueChanged<PaymentMethod?> onMethodChanged;
  final ValueChanged<PaymentCard?> onCardChanged;
  final ValueChanged<int> onInstallmentsChanged;

  const PaymentMethodSelector({
    super.key,
    required this.selectedMethod,
    required this.selectedCard,
    required this.cards,
    required this.installments,
    required this.onMethodChanged,
    required this.onCardChanged,
    required this.onInstallmentsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Forma de pagamento', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _MethodChip(label: 'Dinheiro', icon: Icons.payments_outlined,  method: PaymentMethod.cash,   selected: selectedMethod, onTap: onMethodChanged),
              const SizedBox(width: 8),
              _MethodChip(label: 'PIX',      icon: Icons.bolt_rounded,        method: PaymentMethod.pix,    selected: selectedMethod, onTap: onMethodChanged),
              const SizedBox(width: 8),
              _MethodChip(label: 'Débito',   icon: Icons.credit_card_outlined, method: PaymentMethod.debit,  selected: selectedMethod, onTap: onMethodChanged),
              const SizedBox(width: 8),
              _MethodChip(label: 'Crédito',  icon: Icons.credit_score_rounded, method: PaymentMethod.credit, selected: selectedMethod, onTap: onMethodChanged),
            ],
          ),
        ),
        if (selectedMethod == PaymentMethod.credit) ...[
          const SizedBox(height: 12),
          if (cards.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textMuted, size: 16),
                  SizedBox(width: 8),
                  Text('Cadastre cartões na aba Cartões', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            )
          else ...[
            const Text('Cartão', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: cards.map((card) {
                  final isSelected = card.id == selectedCard?.id;
                  final color = _hexColor(card.color);
                  return GestureDetector(
                    onTap: () => onCardChanged(isSelected ? null : card),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withOpacity(0.18) : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? color : AppColors.surfaceBorder, width: isSelected ? 1.2 : 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.credit_card_rounded, color: isSelected ? color : AppColors.textMuted, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            card.lastFour != null ? '${card.name} ••${card.lastFour}' : card.name,
                            style: TextStyle(
                              color: isSelected ? color : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text('Parcelamento', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [1, 2, 3, 4, 5, 6, 10, 12].map((n) {
                final isSelected = n == installments;
                return GestureDetector(
                  onTap: () => onInstallmentsChanged(n),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.18) : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.surfaceBorder, width: isSelected ? 1.2 : 0.5),
                    ),
                    child: Text(
                      n == 1 ? 'À vista' : '${n}x',
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final PaymentMethod method;
  final PaymentMethod? selected;
  final ValueChanged<PaymentMethod?> onTap;

  const _MethodChip({required this.label, required this.icon, required this.method, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = method == selected;
    final color = isSelected ? AppColors.primary : AppColors.textMuted;
    return GestureDetector(
      onTap: () => onTap(isSelected ? null : method),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.surfaceBorder, width: isSelected ? 1.2 : 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
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
