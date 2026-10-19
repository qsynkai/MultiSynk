import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'providers/finance_provider.dart';
import 'providers/fiorino_provider.dart';
import 'providers/fixed_expense_provider.dart';
import 'providers/payment_card_provider.dart';
import 'providers/shopping_provider.dart';
import 'providers/studio_provider.dart';
import 'providers/task_provider.dart';
import 'providers/vehicle_provider.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'screens/fiorino_screen.dart';
import 'screens/home_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/vehicles_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/studio_screen.dart';
import 'screens/cards_screen.dart';
import 'screens/planning_screen.dart';

class MultiSynkApp extends ConsumerStatefulWidget {
  const MultiSynkApp({super.key});

  @override
  ConsumerState<MultiSynkApp> createState() => _MultiSynkAppState();
}

class _MultiSynkAppState extends ConsumerState<MultiSynkApp> with WidgetsBindingObserver {
  int _currentIndex = 0;
  StreamSubscription<Uri?>? _widgetSub;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SyncService.dataVersion.addListener(_reloadAll);
    _startSyncTimer();
    SyncService.syncAll();
    if (kIsWeb) return;
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
    _widgetSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SyncService.dataVersion.removeListener(_reloadAll);
    _syncTimer?.cancel();
    _widgetSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SyncService.syncAll();
      _startSyncTimer();
    } else if (state == AppLifecycleState.paused) {
      _syncTimer?.cancel();
    }
  }

  // Pulls the partner's changes while the app is open.
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) => SyncService.syncAll());
  }

  void _reloadAll() {
    ref.read(financeProvider.notifier).load();
    ref.read(taskProvider.notifier).load();
    ref.read(fiorinoProvider.notifier).load();
    ref.read(studioProvider.notifier).load();
    ref.read(fixedExpenseProvider.notifier).load();
    ref.read(paymentCardProvider.notifier).load();
    ref.read(vehicleProvider.notifier).load();
    ref.read(shoppingProvider.notifier).load();
  }

  // multisynk://tab/<index> switches tab; multisynk://fiorino opens the Fiorino entry screen.
  void _handleWidgetUri(Uri? uri) {
    if (uri == null || !mounted) return;
    if (uri.host == 'tab') {
      final index = int.tryParse(uri.pathSegments.firstOrNull ?? '');
      if (index != null && index >= 0 && index < 7) {
        Navigator.of(context).popUntil((r) => r.isFirst);
        setState(() => _currentIndex = index);
      }
    } else if (uri.host == 'fiorino') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FiorinoScreen()));
    }
  }

  final _screens = const [
    HomeScreen(),
    FinanceScreen(),
    CardsScreen(),
    PlanningScreen(),
    VehiclesScreen(),
    TasksScreen(),
    StudioScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.surfaceBorder, width: 0.5)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
            top: 4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Início', index: 0, current: _currentIndex, onTap: _onTap),
              _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Finanças', index: 1, current: _currentIndex, onTap: _onTap),
              _NavItem(icon: Icons.credit_card_rounded, label: 'Cartões', index: 2, current: _currentIndex, onTap: _onTap),
              _NavItem(icon: Icons.calendar_month_rounded, label: 'Planejar', index: 3, current: _currentIndex, onTap: _onTap),
              _NavItem(icon: Icons.directions_car_rounded, label: 'Garagem', index: 4, current: _currentIndex, onTap: _onTap),
              _NavItem(icon: Icons.checklist_rounded, label: 'Tarefas', index: 5, current: _currentIndex, onTap: _onTap),
              _NavItem(icon: Icons.spa_rounded, label: 'Studio', index: 6, current: _currentIndex, onTap: _onTap),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavItem({required this.icon, required this.label, required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textMuted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
