import 'package:flutter_test/flutter_test.dart';
import 'package:multisynk/models/fiorino_entry.dart';
import 'package:multisynk/models/fixed_expense.dart';
import 'package:multisynk/models/payment_card.dart';
import 'package:multisynk/models/receivable.dart';
import 'package:multisynk/models/shopping_item.dart';
import 'package:multisynk/models/studio_config.dart';
import 'package:multisynk/models/studio_entry.dart';
import 'package:multisynk/models/task.dart';
import 'package:multisynk/models/transaction.dart';
import 'package:multisynk/models/vehicle.dart';

/// Simulates a row coming back from the cloud as JSON: whole doubles become ints (100.0 → 100)
/// and 0/1 flags may come back as booleans.
Map<String, dynamic> asCloudJson(Map<String, dynamic> m, {bool boolFlags = false}) => {
      for (final e in m.entries)
        e.key: switch (e.value) {
          final double d when d == d.roundToDouble() => d.toInt(),
          final int i when boolFlags && (e.key.startsWith('is_')) => i == 1,
          final v => v,
        },
    };

void main() {
  final when = DateTime(2026, 10, 14, 15, 30, 12, 345);

  test('Transaction', () {
    final t = Transaction(
      id: 't1', description: 'Mercado', amount: 100, type: TransactionType.expense, date: when,
      category: 'food', vehicleId: 'meriva-001', paymentMethod: PaymentMethod.credit, cardId: 'c1',
      installments: 3, installmentNumber: 2, installmentGroupId: 'g1',
    );
    for (final map in [t.toMap(), asCloudJson(t.toMap())]) {
      final back = Transaction.fromMap(map);
      expect(back.toMap(), t.toMap());
      expect(back.amount, isA<double>());
    }
  });

  test('Transaction with nulls and defaults', () {
    final back = Transaction.fromMap({
      'id': 'x', 'description': 'd', 'amount': 1, 'type': 'income', 'date': when.toIso8601String(),
    });
    expect(back.installments, 1);
    expect(back.installmentNumber, 1);
    expect(back.paymentMethod, isNull);
    expect(back.type, TransactionType.income);
  });

  test('MaintenanceItem and Vehicle', () {
    final m = MaintenanceItem(id: 'm1', vehicleId: 'v', title: 'Óleo', priority: MaintenancePriority.high,
        dueDate: when, estimatedCost: 250, isDone: true);
    for (final map in [m.toMap(), asCloudJson(m.toMap()), asCloudJson(m.toMap(), boolFlags: true)]) {
      expect(MaintenanceItem.fromMap(map).toMap(), m.toMap());
    }
    const v = Vehicle(id: 'v', name: 'Meriva', brand: 'Chevrolet', model: 'Meriva', color: 'Cinza', plate: 'ABC1D23', year: 2012);
    expect(Vehicle.fromMap(v.toMap()).toMap(), v.toMap());
  });

  test('Task', () {
    final t = Task(id: 't', title: 'Pagar luz', description: 'até sexta', priority: TaskPriority.high,
        aiPriority: TaskPriority.urgent, aiReason: 'vence', category: TaskCategory.financial,
        createdAt: when, dueDate: when, isDone: true);
    for (final map in [t.toMap(), asCloudJson(t.toMap(), boolFlags: true)]) {
      expect(Task.fromMap(map).toMap(), t.toMap());
    }
    expect(t.effectivePriority, TaskPriority.urgent);
  });

  test('Receivable (int amounts from the cloud no longer crash)', () {
    final r = Receivable(id: 'r', description: 'Cliente', expectedAmount: 1500, receivedAmount: 500,
        expectedDate: when, status: ReceivableStatus.partial, isRecurring: true);
    for (final map in [r.toMap(), asCloudJson(r.toMap()), asCloudJson(r.toMap(), boolFlags: true)]) {
      final back = Receivable.fromMap(map);
      expect(back.toMap(), r.toMap());
      expect(back.amountToReceive, 1000);
    }
  });

  test('FiorinoEntry and FiorinoConfig', () {
    final e = FiorinoEntry(id: 'f', amount: 300, date: when, notes: 'ok', safetyPercent: 0.1, maintenancePercent: 0.1, fuelPercent: 0.2);
    for (final map in [e.toMap(), asCloudJson(e.toMap())]) {
      expect(FiorinoEntry.fromMap(map).toMap(), e.toMap());
    }
    expect(e.toSafety + e.toMaintenance + e.toFuel + e.available, closeTo(300, 1e-9));
    const c = FiorinoConfig(safetyPercent: 0.15, maintenancePercent: 0.05, fuelPercent: 0.25);
    expect(FiorinoConfig.fromMap(c.toMap()).toMap(), c.toMap());
    expect(FiorinoConfig.fromMap(const {}).toMap(), const FiorinoConfig().toMap());
  });

  test('StudioEntry and StudioConfig', () {
    final s = StudioEntry(id: 's', amount: 80, type: 'revenue', description: 'Corte', category: 'cabelo', date: when,
        notes: 'n', paymentMethod: PaymentMethod.pix, installments: 2, installmentNumber: 1, installmentGroupId: 'g');
    for (final map in [s.toMap(), asCloudJson(s.toMap())]) {
      expect(StudioEntry.fromMap(map).toMap(), s.toMap());
    }
    const c = StudioConfig(safetyPercent: 0.2, savingsPercent: 0.1);
    expect(StudioConfig.fromMap(c.toMap()).toMap(), c.toMap());
    expect(c.availablePercent, closeTo(0.7, 1e-12));
  });

  test('FixedExpense', () {
    const f = FixedExpense(id: 'f', description: 'Aluguel', amount: 1200, category: 'casa', scope: 'personal', isActive: false, dueDay: 5);
    for (final map in [f.toMap(), asCloudJson(f.toMap()), asCloudJson(f.toMap(), boolFlags: true)]) {
      expect(FixedExpense.fromMap(map).toMap(), f.toMap());
    }
  });

  test('PaymentCard', () {
    const c = PaymentCard(id: 'c', name: 'Nubank', lastFour: '1234', closingDay: 5, dueDay: 12, color: '#123456');
    expect(PaymentCard.fromMap(c.toMap()).toMap(), c.toMap());
  });

  test('ShoppingItem', () {
    final i = ShoppingItem(id: 'i', description: 'Arroz', quantity: 2, estimatedPrice: 25, category: ShoppingCategory.alimentacao,
        isPurchased: true, aiPriority: ShoppingPriority.high, aiReason: 'acabou', createdAt: when);
    for (final map in [i.toMap(), asCloudJson(i.toMap(), boolFlags: true)]) {
      expect(ShoppingItem.fromMap(map).toMap(), i.toMap());
    }
  });

  test('unknown enum values fall back instead of crashing the app', () {
    final t = Task.fromMap({'id': 't', 'title': 'x', 'priority': 'weird', 'category': 'nope', 'created_at': when.toIso8601String()});
    expect(t.priority, TaskPriority.none);
    expect(t.category, TaskCategory.personal);
  });
}
