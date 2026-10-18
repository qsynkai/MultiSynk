import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../providers/task_provider.dart';
import '../providers/shopping_provider.dart';
import '../models/task.dart';
import '../models/shopping_item.dart';
import '../logic/money.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskProvider);
    final shopState = ref.watch(shoppingProvider);
    final isTasksTab = _tab.index == 0;

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTasksTab ? 'Tarefas' : 'Lista de Compras',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isTasksTab ? 'Organizado pela IA' : 'IA prioriza o que é urgente',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Botão IA
                      if (isTasksTab && taskState.pendingTasks.isNotEmpty)
                        _AIButton(
                          isAnalyzing: taskState.isAnalyzing,
                          onTap: () => ref.read(taskProvider.notifier).analyzeWithAI(),
                        )
                      else if (!isTasksTab && shopState.pendingItems.isNotEmpty)
                        _AIButton(
                          isAnalyzing: shopState.isAnalyzing,
                          onTap: () => ref.read(shoppingProvider.notifier).analyzeWithAI(),
                        ),
                      const SizedBox(width: 8),
                      // Botão Novo
                      GestureDetector(
                        onTap: () => isTasksTab
                            ? _showAddTask(context)
                            : _showAddItem(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('Novo', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

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
                indicator: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(9)),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(text: 'Tarefas${taskState.pendingTasks.isNotEmpty ? " (${taskState.pendingTasks.length})" : ""}'),
                  Tab(text: 'Compras${shopState.pendingItems.isNotEmpty ? " (${shopState.pendingItems.length})" : ""}'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _TasksTab(state: taskState, onAdd: () => _showAddTask(context)),
                  _ShoppingTab(state: shopState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTask(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    TaskCategory category = TaskCategory.personal;

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
              const Text('Nova tarefa', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'O que precisa fazer?'),
                autofocus: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Detalhes (opcional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              const Text('Categoria', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TaskCategory.values.map((c) {
                  final selected = category == c;
                  final label = switch (c) {
                    TaskCategory.financial => 'Financeiro',
                    TaskCategory.vehicle => 'Veículo',
                    TaskCategory.personal => 'Pessoal',
                    TaskCategory.work => 'Trabalho',
                    TaskCategory.health => 'Saúde',
                    TaskCategory.other => 'Outro',
                  };
                  return GestureDetector(
                    onTap: () => setState(() => category = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary.withOpacity(0.2) : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppColors.primary : Colors.transparent),
                      ),
                      child: Text(label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (titleCtrl.text.isEmpty) return;
                  ref.read(taskProvider.notifier).addTask(Task(
                    id: const Uuid().v4(),
                    title: titleCtrl.text,
                    description: descCtrl.text.isEmpty ? null : descCtrl.text,
                    category: category,
                    createdAt: DateTime.now(),
                  ));
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddItem(BuildContext context) {
    final descCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    ShoppingCategory category = ShoppingCategory.alimentacao;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Adicionar item', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'O que comprar?', hintText: 'ex: Leite, Shampoo, Fone...'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: priceCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Preço estimado (R\$)', hintText: '0,00'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Qtd'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Categoria', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ShoppingCategory.values.map((c) {
                  final selected = category == c;
                  final label = switch (c) {
                    ShoppingCategory.alimentacao => '🛒 Alimentação',
                    ShoppingCategory.limpeza => '🧹 Limpeza',
                    ShoppingCategory.higiene => '🧴 Higiene',
                    ShoppingCategory.eletronico => '📱 Eletrônico',
                    ShoppingCategory.roupa => '👕 Roupa',
                    ShoppingCategory.farmacia => '💊 Farmácia',
                    ShoppingCategory.outro => '📦 Outro',
                  };
                  return GestureDetector(
                    onTap: () => setState(() => category = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary.withOpacity(0.2) : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppColors.primary : Colors.transparent),
                      ),
                      child: Text(label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textSecondary, fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (descCtrl.text.isEmpty) return;
                  final qty = int.tryParse(qtyCtrl.text) ?? 1;
                  final price = parseMoney(priceCtrl.text);
                  ref.read(shoppingProvider.notifier).add(ShoppingItem(
                    id: const Uuid().v4(),
                    description: descCtrl.text,
                    quantity: qty.clamp(1, 999),
                    estimatedPrice: price,
                    category: category,
                    createdAt: DateTime.now(),
                  ));
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AIButton extends StatelessWidget {
  final bool isAnalyzing;
  final VoidCallback onTap;
  const _AIButton({required this.isAnalyzing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isAnalyzing ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(isAnalyzing ? 0.1 : 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAnalyzing)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
            else
              const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 14),
            const SizedBox(width: 6),
            Text(
              isAnalyzing ? 'Analisando...' : 'Analisar IA',
              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasksTab extends StatelessWidget {
  final TaskState state;
  final VoidCallback onAdd;
  const _TasksTab({required this.state, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (state.pendingTasks.isEmpty) return _EmptyState(label: 'Mente livre!', sublabel: 'Nenhuma tarefa pendente.', icon: Icons.check_circle_outline_rounded, onAdd: onAdd);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: state.pendingTasks.length + (state.doneTasks.isNotEmpty ? 1 : 0),
      itemBuilder: (context, i) {
        if (i < state.pendingTasks.length) {
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: _TaskTile(task: state.pendingTasks[i]));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Concluídas', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
            ...state.doneTasks.map((t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _TaskTile(task: t))),
          ],
        );
      },
    );
  }
}

class _ShoppingTab extends ConsumerWidget {
  final ShoppingState state;
  const _ShoppingTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    if (state.pendingItems.isEmpty && state.purchasedItems.isEmpty) {
      return _EmptyState(
        label: 'Lista vazia!',
        sublabel: 'Adicione itens para comprar.',
        icon: Icons.shopping_cart_outlined,
        onAdd: null,
      );
    }

    return Column(
      children: [
        // Banner total estimado + IA
        if (state.pendingItems.isNotEmpty && state.totalEstimated > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: AppColors.textSecondary, size: 16),
                  const SizedBox(width: 8),
                  Text('${state.pendingItems.length} itens · ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  Text('~${fmt.format(state.totalEstimated)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

        // Lista
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              if (state.pendingItems.any((i) => i.aiPriority != null))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 0.5),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 14),
                        SizedBox(width: 8),
                        Expanded(child: Text('IA ordenou por prioridade real de compra.', style: TextStyle(color: AppColors.primary, fontSize: 12))),
                      ],
                    ),
                  ),
                ),
              ...state.pendingItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ShoppingTile(item: item),
              )),
              if (state.purchasedItems.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Comprados', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                    GestureDetector(
                      onTap: () => ref.read(shoppingProvider.notifier).clearPurchased(),
                      child: const Text('Limpar', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                    ),
                  ],
                ),
                ...state.purchasedItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ShoppingTile(item: item),
                )),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShoppingTile extends ConsumerWidget {
  final ShoppingItem item;
  const _ShoppingTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final priorityColor = switch (item.effectivePriority) {
      ShoppingPriority.urgent => AppColors.danger,
      ShoppingPriority.high   => AppColors.warning,
      ShoppingPriority.medium => AppColors.primary,
      ShoppingPriority.low    => AppColors.textMuted,
      ShoppingPriority.none   => AppColors.surfaceBorder,
    };
    final priorityLabel = switch (item.effectivePriority) {
      ShoppingPriority.urgent => 'Urgente',
      ShoppingPriority.high   => 'Alta',
      ShoppingPriority.medium => 'Média',
      ShoppingPriority.low    => 'Baixa',
      ShoppingPriority.none   => null,
    };
    final catIcon = switch (item.category) {
      ShoppingCategory.alimentacao => Icons.restaurant_outlined,
      ShoppingCategory.limpeza     => Icons.cleaning_services_outlined,
      ShoppingCategory.higiene     => Icons.sanitizer_outlined,
      ShoppingCategory.eletronico  => Icons.devices_outlined,
      ShoppingCategory.roupa       => Icons.checkroom_outlined,
      ShoppingCategory.farmacia    => Icons.local_pharmacy_outlined,
      ShoppingCategory.outro       => Icons.shopping_bag_outlined,
    };

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
      ),
      onDismissed: (_) => ref.read(shoppingProvider.notifier).delete(item.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isPurchased ? AppColors.surfaceLight.withOpacity(0.5) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => ref.read(shoppingProvider.notifier).togglePurchased(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: item.isPurchased ? AppColors.success : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: item.isPurchased ? AppColors.success : AppColors.surfaceBorder, width: 1.5),
                ),
                child: item.isPurchased ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.quantity > 1 ? '${item.description} ×${item.quantity}' : item.description,
                    style: TextStyle(
                      color: item.isPurchased ? AppColors.textMuted : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: item.isPurchased ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.aiReason != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 11, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(child: Text(item.aiReason!, style: const TextStyle(color: AppColors.primary, fontSize: 11))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(catIcon, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      if (priorityLabel != null && !item.isPurchased)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: priorityColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: Text(priorityLabel, style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (item.estimatedPrice != null && !item.isPurchased)
              Text(
                fmt.format(item.estimatedPrice! * item.quantity),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final Task task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = switch (task.effectivePriority) {
      TaskPriority.urgent => AppColors.danger,
      TaskPriority.high   => AppColors.warning,
      TaskPriority.medium => AppColors.primary,
      TaskPriority.low    => AppColors.textMuted,
      TaskPriority.none   => AppColors.surfaceBorder,
    };
    final priorityLabel = switch (task.effectivePriority) {
      TaskPriority.urgent => 'Urgente',
      TaskPriority.high   => 'Alta',
      TaskPriority.medium => 'Média',
      TaskPriority.low    => 'Baixa',
      TaskPriority.none   => null,
    };
    final categoryIcon = switch (task.category) {
      TaskCategory.financial => Icons.account_balance_wallet_outlined,
      TaskCategory.vehicle   => Icons.directions_car_outlined,
      TaskCategory.work      => Icons.work_outline_rounded,
      TaskCategory.health    => Icons.favorite_outline_rounded,
      TaskCategory.personal  => Icons.person_outline_rounded,
      TaskCategory.other     => Icons.more_horiz_rounded,
    };

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
      ),
      onDismissed: (_) => ref.read(taskProvider.notifier).deleteTask(task.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: task.isDone ? AppColors.surfaceLight.withOpacity(0.5) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => ref.read(taskProvider.notifier).toggleDone(task),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: task.isDone ? AppColors.success : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: task.isDone ? AppColors.success : AppColors.surfaceBorder, width: 1.5),
                ),
                child: task.isDone ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title,
                      style: TextStyle(
                        color: task.isDone ? AppColors.textMuted : AppColors.textPrimary,
                        fontSize: 14, fontWeight: FontWeight.w500,
                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                      )),
                  if (task.aiReason != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 11, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(child: Text(task.aiReason!, style: const TextStyle(color: AppColors.primary, fontSize: 11))),
                      ],
                    ),
                  ],
                  if (task.description != null) ...[
                    const SizedBox(height: 4),
                    Text(task.description!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(categoryIcon, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      if (priorityLabel != null && !task.isDone)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: priorityColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: Text(priorityLabel, style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final VoidCallback? onAdd;
  const _EmptyState({required this.label, required this.sublabel, required this.icon, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(sublabel, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
          if (onAdd != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Adicionar')),
          ],
        ],
      ),
    );
  }
}
