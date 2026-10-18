import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'theme/app_theme.dart';
import 'screens/fiorino_screen.dart';
import 'screens/home_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/vehicles_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/studio_screen.dart';
import 'screens/cards_screen.dart';

class MultiSynkApp extends StatefulWidget {
  const MultiSynkApp({super.key});

  @override
  State<MultiSynkApp> createState() => _MultiSynkAppState();
}

class _MultiSynkAppState extends State<MultiSynkApp> {
  int _currentIndex = 0;
  StreamSubscription<Uri?>? _widgetSub;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
    _widgetSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
  }

  @override
  void dispose() {
    _widgetSub?.cancel();
    super.dispose();
  }

  // multisynk://tab/<index> switches tab; multisynk://fiorino opens the Fiorino entry screen.
  void _handleWidgetUri(Uri? uri) {
    if (uri == null || !mounted) return;
    if (uri.host == 'tab') {
      final index = int.tryParse(uri.pathSegments.firstOrNull ?? '');
      if (index != null && index >= 0 && index < _screens.length) {
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Início', index: 0, current: _currentIndex, onTap: _onTap),
                _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Finanças', index: 1, current: _currentIndex, onTap: _onTap),
                _NavItem(icon: Icons.credit_card_rounded, label: 'Cartões', index: 2, current: _currentIndex, onTap: _onTap),
                _NavItem(icon: Icons.directions_car_rounded, label: 'Garagem', index: 3, current: _currentIndex, onTap: _onTap),
                _NavItem(icon: Icons.checklist_rounded, label: 'Tarefas', index: 4, current: _currentIndex, onTap: _onTap),
                _NavItem(icon: Icons.spa_rounded, label: 'Studio', index: 5, current: _currentIndex, onTap: _onTap),
              ],
            ),
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
