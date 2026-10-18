import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class WidgetService {
  static final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');
  static String? _lastSignature;

  static Future<void> update({
    required double weeklyBudget,
    required double receivables,
    required double monthExpenses,
    required double pendingFixed,
    double? fiorinoToday,
    List<String> topTasks = const [],
  }) async {
    if (kIsWeb) return;

    final data = <String, String>{
      'weekly_budget': _fmt.format(weeklyBudget),
      'budget_negative': weeklyBudget < 0 ? '1' : '0',
      'receivables': _fmt.format(receivables),
      'month_expenses': _fmt.format(monthExpenses),
      'pending_fixed': pendingFixed > 0 ? '${_fmt.format(pendingFixed)} em fixas já descontadas' : '',
      'fiorino_today': fiorinoToday != null ? _fmt.format(fiorinoToday) : 'não lançado',
      'task_1': topTasks.isNotEmpty ? topTasks[0] : '',
      'task_2': topTasks.length > 1 ? topTasks[1] : '',
      'task_3': topTasks.length > 2 ? topTasks[2] : '',
    };

    // HomeScreen rebuilds often; only hit the platform channel when values change.
    final signature = data.values.join('|');
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    try {
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      await HomeWidget.saveWidgetData<String>(
        'updated_at',
        DateFormat('HH:mm').format(DateTime.now()),
      );
      await HomeWidget.updateWidget(androidName: 'BudgetWidget');
    } catch (_) {}
  }
}
