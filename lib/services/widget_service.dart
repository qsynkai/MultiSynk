import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class WidgetService {
  static final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');

  static Future<void> update({
    required double weeklyBudget,
    required double totalIncome,
    required double totalExpenses,
    double? fiorinoToday,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('weekly_budget',  _fmt.format(weeklyBudget));
      await HomeWidget.saveWidgetData<String>('total_income',   _fmt.format(totalIncome));
      await HomeWidget.saveWidgetData<String>('total_expenses', _fmt.format(totalExpenses));
      await HomeWidget.saveWidgetData<String>(
        'fiorino_today',
        fiorinoToday != null ? _fmt.format(fiorinoToday) : '—',
      );
      await HomeWidget.updateWidget(androidName: 'BudgetWidget');
    } catch (_) {}
  }
}
