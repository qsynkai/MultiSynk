import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/shopping_item.dart';
import '../services/ai_service.dart';

class ShoppingState {
  final List<ShoppingItem> items;
  final bool isLoading;
  final bool isAnalyzing;

  const ShoppingState({this.items = const [], this.isLoading = false, this.isAnalyzing = false});

  List<ShoppingItem> get pendingItems => items.where((i) => !i.isPurchased).toList();
  List<ShoppingItem> get purchasedItems => items.where((i) => i.isPurchased).toList();
  double get totalEstimated => pendingItems.fold(0, (s, i) => s + (i.estimatedPrice ?? 0) * i.quantity);

  ShoppingState copyWith({List<ShoppingItem>? items, bool? isLoading, bool? isAnalyzing}) =>
      ShoppingState(items: items ?? this.items, isLoading: isLoading ?? this.isLoading, isAnalyzing: isAnalyzing ?? this.isAnalyzing);
}

class ShoppingNotifier extends StateNotifier<ShoppingState> {
  ShoppingNotifier() : super(const ShoppingState(isLoading: true)) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final items = await DatabaseHelper.instance.getShoppingItems();
    state = ShoppingState(items: items);
  }

  Future<void> add(ShoppingItem item) async {
    await DatabaseHelper.instance.insertShoppingItem(item);
    await load();
  }

  Future<void> togglePurchased(ShoppingItem item) async {
    final updated = item.copyWith(isPurchased: !item.isPurchased);
    await DatabaseHelper.instance.updateShoppingItem(updated);
    await load();
  }

  Future<void> delete(String id) async {
    await DatabaseHelper.instance.deleteShoppingItem(id);
    await load();
  }

  Future<void> clearPurchased() async {
    await DatabaseHelper.instance.clearPurchasedItems();
    await load();
  }

  Future<void> analyzeWithAI() async {
    final pending = state.pendingItems;
    if (pending.isEmpty) return;
    state = state.copyWith(isAnalyzing: true);
    try {
      final analyzed = await AiService.analyzeShoppingPriorities(pending);
      for (final item in analyzed) {
        await DatabaseHelper.instance.updateShoppingItem(item);
      }
      // Sort by priority
      final priorityOrder = {ShoppingPriority.urgent: 0, ShoppingPriority.high: 1, ShoppingPriority.medium: 2, ShoppingPriority.low: 3, ShoppingPriority.none: 4};
      final allItems = await DatabaseHelper.instance.getShoppingItems();
      allItems.sort((a, b) {
        if (a.isPurchased != b.isPurchased) return a.isPurchased ? 1 : -1;
        return (priorityOrder[a.effectivePriority] ?? 4).compareTo(priorityOrder[b.effectivePriority] ?? 4);
      });
      state = ShoppingState(items: allItems);
    } finally {
      state = state.copyWith(isAnalyzing: false);
    }
  }
}

final shoppingProvider = StateNotifierProvider<ShoppingNotifier, ShoppingState>(
  (ref) => ShoppingNotifier(),
);
