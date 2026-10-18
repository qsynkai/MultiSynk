import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../providers/vehicle_provider.dart';
import '../providers/fiorino_provider.dart';
import '../models/vehicle.dart';
import '../logic/money.dart';
import 'fiorino_screen.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehicleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Minha Garagem', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text('Controle dos seus veículos', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (vehicles.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text('Carregando veículos...', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: EdgeInsets.fromLTRB(20, i == 0 ? 20 : 14, 20, 0),
                    child: _VehicleCard(vehicle: vehicles[i]),
                  ),
                  childCount: vehicles.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends ConsumerWidget {
  final Vehicle vehicle;
  const _VehicleCard({required this.vehicle});

  bool get _isMeriva => vehicle.id == 'meriva-001';

  Color get _cardColorStart => _isMeriva ? const Color(0xFF1C1C2E) : const Color(0xFF1A2030);
  Color get _cardColorEnd => _isMeriva ? const Color(0xFF0D0D1A) : const Color(0xFF0D1520);
  Color get _accentColor => _isMeriva ? AppColors.primary : AppColors.accent;
  Color get _vehicleDotColor => _isMeriva ? const Color(0xFF4A4A5E) : const Color(0xFFD0D0E0);
  String get _carImageAsset => _isMeriva ? 'assets/images/meriva.webp' : 'assets/images/fiorino.png';
  String get _logoAsset => _isMeriva ? 'assets/images/logo_chevrolet.svg' : 'assets/images/logo_fiat.svg';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final urgent = vehicle.pendingItems.where((i) => i.priority == MaintenancePriority.urgent).length;
    final pending = vehicle.pendingItems.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withOpacity(0.2), width: 0.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do veículo — com ilustração SVG
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_cardColorStart, _cardColorEnd],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: info à esquerda, foto do carro à direita
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 0, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              vehicle.name,
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 10, height: 10,
                                  decoration: BoxDecoration(
                                    color: _vehicleDotColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  vehicle.color,
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                ),
                                if (vehicle.year != null) ...[
                                  Text(' · ', style: TextStyle(color: Colors.white.withOpacity(0.3))),
                                  Text('${vehicle.year}', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('gasto total', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
                            Text(fmt.format(vehicle.totalSpent), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      // Foto do carro à direita
                      Image.asset(
                        _carImageAsset,
                        height: 130,
                        width: 170,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),

                // Badges
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      _VehicleBadge(
                        label: '$pending pendência${pending != 1 ? 's' : ''}',
                        icon: Icons.build_outlined,
                        color: pending > 0 ? AppColors.warning : Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                      if (urgent > 0)
                        _VehicleBadge(
                          label: '$urgent urgente${urgent != 1 ? 's' : ''}',
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.danger,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Manutenções pendentes
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Manutenções',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                    ),
                    GestureDetector(
                      onTap: () => _showAddMaintenance(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: _accentColor, size: 14),
                            const SizedBox(width: 4),
                            Text('Adicionar', style: TextStyle(color: _accentColor, fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (vehicle.pendingItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                        SizedBox(width: 8),
                        Text('Tudo em dia!', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  )
                else
                  ...vehicle.pendingItems.take(3).map((item) => _MaintenanceTile(item: item, accentColor: _accentColor, vehicleId: vehicle.id)),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Registrar gasto',
                        icon: Icons.receipt_long_rounded,
                        color: _accentColor,
                        onTap: () => _showAddExpense(context, ref),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        label: 'Ver histórico',
                        icon: Icons.history_rounded,
                        color: AppColors.textSecondary,
                        onTap: () => _showHistory(context),
                      ),
                    ),
                  ],
                ),
                if (vehicle.id == 'fiorino-001') ...[
                  const SizedBox(height: 10),
                  _FiorinoQuickEntry(vehicleId: vehicle.id),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMaintenance(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    MaintenancePriority priority = MaintenancePriority.medium;
    double? cost;

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
              Text('Nova manutenção — ${vehicle.name}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'O que precisa fazer?', hintText: 'ex: Troca de óleo'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              const Text('Prioridade', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: MaintenancePriority.values.map((p) {
                  final selected = priority == p;
                  final color = switch (p) {
                    MaintenancePriority.urgent => AppColors.danger,
                    MaintenancePriority.high => AppColors.warning,
                    MaintenancePriority.medium => AppColors.primary,
                    MaintenancePriority.low => AppColors.textMuted,
                  };
                  final label = switch (p) {
                    MaintenancePriority.urgent => 'Urgente',
                    MaintenancePriority.high => 'Alta',
                    MaintenancePriority.medium => 'Média',
                    MaintenancePriority.low => 'Baixa',
                  };
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => priority = p),
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? color.withOpacity(0.2) : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: selected ? color : Colors.transparent),
                        ),
                        child: Text(label,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: selected ? color : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (titleCtrl.text.isEmpty) return;
                  ref.read(vehicleProvider.notifier).addMaintenanceItem(
                    vehicle.id,
                    MaintenanceItem(
                      id: const Uuid().v4(),
                      vehicleId: vehicle.id,
                      title: titleCtrl.text,
                      priority: priority,
                    ),
                  );
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

  void _showAddExpense(BuildContext context, WidgetRef ref) {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gasto — ${vehicle.name}',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Descrição', hintText: 'ex: Pneu dianteiro'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Valor (R\$)', hintText: '0,00'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final amount = parseMoney(amountCtrl.text);
                if (descCtrl.text.trim().isEmpty || amount == null) return;
                ref.read(vehicleProvider.notifier).addExpense(
                  vehicle.id,
                  descCtrl.text.trim(),
                  amount,
                  DateTime.now(),
                );
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const Center(child: Text('Histórico em breve', style: TextStyle(color: AppColors.textSecondary))),
    );
  }
}

class _VehicleBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _VehicleBadge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _MaintenanceTile extends ConsumerWidget {
  final MaintenanceItem item;
  final Color accentColor;
  final String vehicleId;

  const _MaintenanceTile({required this.item, required this.accentColor, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = switch (item.priority) {
      MaintenancePriority.urgent => AppColors.danger,
      MaintenancePriority.high => AppColors.warning,
      MaintenancePriority.medium => AppColors.primary,
      MaintenancePriority.low => AppColors.textMuted,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 36,
            decoration: BoxDecoration(color: priorityColor, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          GestureDetector(
            onTap: () => ref.read(vehicleProvider.notifier).toggleMaintenanceDone(item),
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
              ),
              child: const Icon(Icons.check_rounded, size: 16, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2), width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _FiorinoQuickEntry extends ConsumerWidget {
  final String vehicleId;
  const _FiorinoQuickEntry({required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fiorino = ref.watch(fiorinoProvider);
    final hasToday = fiorino.todayEntry != null;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FiorinoScreen())),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D1F0D), Color(0xFF162616)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasToday ? AppColors.success.withOpacity(0.4) : AppColors.success.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasToday ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
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
                    hasToday ? 'Entrada de hoje registrada' : 'Registrar entrada do dia',
                    style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    hasToday
                        ? fmt.format(fiorino.todayEntry!.amount)
                        : 'Toque para abrir os cofrinhos',
                    style: TextStyle(color: AppColors.success.withOpacity(0.7), fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.success.withOpacity(0.5), size: 14),
          ],
        ),
      ),
    );
  }
}
