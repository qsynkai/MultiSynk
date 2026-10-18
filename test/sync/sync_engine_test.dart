import 'package:flutter_test/flutter_test.dart';
import 'package:multisynk/database/database_helper.dart';
import 'package:multisynk/logic/budget.dart';
import 'package:multisynk/models/fiorino_entry.dart';
import 'package:multisynk/models/fixed_expense.dart';
import 'package:multisynk/models/payment_card.dart';
import 'package:multisynk/models/receivable.dart';
import 'package:multisynk/models/studio_config.dart';
import 'package:multisynk/models/task.dart';
import 'package:multisynk/models/transaction.dart';
import 'package:multisynk/models/vehicle.dart';
import 'package:multisynk/sync/sync_engine.dart';

import '../support/fake_remote.dart';
import '../support/test_db.dart';

const home = 'household-1';

Transaction tx(String id, double amount, {DateTime? date, TransactionType type = TransactionType.expense}) =>
    Transaction(id: id, description: id, amount: amount, type: type, date: date ?? DateTime(2026, 10, 14, 12));

class Device {
  Device(String name, this.server, this.clock) : db = newTestDb(name, clock);
  final DatabaseHelper db;
  final FakeServer server;
  final TestClock clock;
  final cursors = MemoryCursors();

  Future<SyncReport> sync([String household = home]) => SyncEngine(db, server, cursors).run(household);

  /// Everything a user can see, normalized for comparison between devices.
  Future<Map<String, Object>> snapshot() async => {
        'transactions': {for (final t in await db.getTransactions()) t.id: t.toMap()},
        'tasks': {for (final t in await db.getTasks(includeDone: true)) t.id: t.toMap()},
        'receivables': {for (final r in await db.getReceivables()) r.id: r.toMap()},
        'vehicles': {for (final v in await db.getVehicles()) v.id: v.toMap()},
        'maintenance': {
          for (final v in await db.getVehicles())
            for (final m in v.maintenanceItems) m.id: m.toMap()
        },
        'fiorino': {for (final f in await db.getFiorinoEntries()) f.id: f.toMap()},
        'fiorinoConfig': (await db.getFiorinoConfig()).toMap(),
        'studio': {for (final s in await db.getStudioEntries()) s.id: s.toMap()},
        'studioConfig': (await db.getStudioConfig()).toMap(),
        'fixed': {for (final f in await db.getFixedExpenses()) f.id: f.toMap()},
        'cards': {for (final c in await db.getPaymentCards()) c.id: c.toMap()},
        'shopping': {for (final s in await db.getShoppingItems()) s.id: s.toMap()},
      };
}

Future<void> syncAll(List<Device> devices, {int rounds = 2}) async {
  for (var i = 0; i < rounds; i++) {
    for (final d in devices) {
      await d.sync();
    }
  }
}

void main() {
  late FakeServer server;
  late TestClock clock;
  late Device igor;
  late Device partner;

  setUp(() {
    server = FakeServer();
    clock = TestClock(10000);
    igor = Device('igor', server, clock);
    partner = Device('partner', server, clock);
  });

  tearDown(() async {
    await igor.db.close();
    await partner.db.close();
  });

  test('a fresh device receives every kind of data exactly', () async {
    final d = DateTime(2026, 10, 14, 9, 30);
    await igor.db.insertTransaction(tx('salario', 5000, type: TransactionType.income));
    await igor.db.insertTransaction(Transaction(
        id: 'tv-1', description: 'TV (1/3)', amount: 1000.01, type: TransactionType.expense, date: d,
        paymentMethod: PaymentMethod.credit, cardId: 'nubank', installments: 3, installmentNumber: 1, installmentGroupId: 'g'));
    await igor.db.insertTask(Task(id: 'luz', title: 'Pagar luz', createdAt: d, priority: TaskPriority.high));
    await igor.db.insertReceivable(Receivable(id: 'r', description: 'Cliente', expectedAmount: 800, expectedDate: d));
    await igor.db.insertFiorinoEntry(FiorinoEntry(id: 'f', amount: 350, date: d, safetyPercent: 0.1, maintenancePercent: 0.1));
    await igor.db.saveFiorinoConfig(const FiorinoConfig(safetyPercent: 0.15, maintenancePercent: 0.05, fuelPercent: 0.25));
    await igor.db.saveStudioConfig(const StudioConfig(safetyPercent: 0.2, savingsPercent: 0.1));
    await igor.db.insertFixedExpense(const FixedExpense(id: 'aluguel', description: 'Aluguel', amount: 1200, scope: 'personal', dueDay: 5));
    await igor.db.insertPaymentCard(const PaymentCard(id: 'nubank', name: 'Nubank', closingDay: 5, dueDay: 12));
    await igor.db.insertMaintenanceItem(const MaintenanceItem(id: 'oleo', vehicleId: 'meriva-001', title: 'Óleo', estimatedCost: 250));
    await igor.db.updateVehicle(const Vehicle(id: 'meriva-001', name: 'Meriva', brand: 'Chevrolet', model: 'Meriva', color: 'Cinza Chumbo', plate: 'ABC1D23'));

    await igor.sync();
    await partner.sync();

    expect(await partner.snapshot(), await igor.snapshot());
    final meriva = (await partner.db.getVehicles()).firstWhere((v) => v.id == 'meriva-001');
    expect(meriva.plate, 'ABC1D23', reason: "partner's untouched seed must not overwrite the edited vehicle");
  });

  test('both edit different things: everything converges on both devices', () async {
    await igor.db.insertTransaction(tx('mercado', 300));
    await syncAll([igor, partner]);

    clock.advance();
    await partner.db.insertTransaction(tx('farmacia', 45.9));
    await igor.db.insertTask(Task(id: 'carro', title: 'Revisão', createdAt: DateTime(2026, 10, 1)));
    await syncAll([igor, partner]);

    final a = await igor.snapshot();
    expect(await partner.snapshot(), a);
    expect((a['transactions'] as Map).keys, containsAll(['mercado', 'farmacia']));
  });

  test('same row edited on both devices: the most recent edit wins everywhere', () async {
    await igor.db.insertTransaction(tx('conta', 100));
    await syncAll([igor, partner]);

    clock.now = 20000;
    await igor.db.insertTransaction(tx('conta', 111));
    clock.now = 30000;
    await partner.db.insertTransaction(tx('conta', 222));

    // Worst order: the newer edit reaches the server first.
    await partner.sync();
    await igor.sync();
    await partner.sync();

    expect((await igor.db.getTransactions()).single.amount, 222);
    expect((await partner.db.getTransactions()).single.amount, 222);
  });

  test('deletions propagate', () async {
    await igor.db.insertTransaction(tx('apagar', 10));
    await igor.db.insertTransaction(tx('manter', 20));
    await syncAll([igor, partner]);

    clock.advance();
    await partner.db.deleteTransaction('apagar');
    await syncAll([igor, partner]);

    expect((await igor.db.getTransactions()).map((t) => t.id), ['manter']);
    expect(await partner.db.pendingDeletions(), isEmpty);
    expect(server.liveRows(home, 'transactions').map((r) => r['id']), ['manter']);
  });

  test('delete vs. later edit: the later action wins', () async {
    await igor.db.insertTransaction(tx('x', 10));
    await igor.db.insertTransaction(tx('y', 10));
    await syncAll([igor, partner]);

    clock.now = 20000;
    await igor.db.deleteTransaction('x'); // delete first...
    clock.now = 30000;
    await partner.db.insertTransaction(tx('x', 99)); // ...then edited: edit wins

    clock.now = 40000;
    await igor.db.insertTransaction(tx('y', 55)); // edit first...
    clock.now = 50000;
    await partner.db.deleteTransaction('y'); // ...then deleted: deletion wins

    await syncAll([igor, partner], rounds: 3);

    for (final d in [igor, partner]) {
      final txs = await d.db.getTransactions();
      expect(txs.map((t) => t.id), ['x']);
      expect(txs.single.amount, 99);
    }
  });

  test('offline edits pile up and go up in one sync', () async {
    for (var i = 0; i < 30; i++) {
      clock.advance(1);
      await igor.db.insertTransaction(tx('off-$i', i + 0.5));
    }
    clock.advance();
    await igor.db.deleteTransaction('off-3');
    final report = await igor.sync();
    expect(report.pushedRows, greaterThanOrEqualTo(29));
    await partner.sync();
    expect((await partner.db.getTransactions()).length, 29);
  });

  test('second sync with nothing new does nothing', () async {
    await igor.db.insertTransaction(tx('a', 1));
    await syncAll([igor, partner]);
    final upsertsBefore = server.upserts;
    final r1 = await igor.sync();
    final r2 = await partner.sync();
    expect(r1.pushedRows + r1.pulledChanges + r2.pushedRows + r2.pulledChanges, 0);
    expect(server.upserts, upsertsBefore);
  });

  test('more rows than a page (1200) arrive complete', () async {
    for (var i = 0; i < 1200; i++) {
      clock.advance(1);
      await igor.db.insertTransaction(tx('t$i', 1));
    }
    await igor.sync();
    await partner.sync();
    expect((await partner.db.getTransactions()).length, 1200);
  });

  test('joining another household uploads this device\'s data there', () async {
    await igor.db.insertTransaction(tx('dela', 77));
    await igor.sync('household-old');
    await igor.db.markAllDirty();
    await igor.cursors.clear();
    await igor.sync('household-new');
    expect(server.liveRows('household-new', 'transactions').map((r) => r['id']), contains('dela'));
  });

  test('money values survive the round trip to the cent and budgets match on both devices', () async {
    final now = DateTime(2026, 10, 14, 15);
    final amounts = [0.01, 0.1, 0.2, 19.99, 33.34, 33.33, 1234.56, 99999.99, 100.0];
    for (var i = 0; i < amounts.length; i++) {
      await igor.db.insertTransaction(tx('v$i', amounts[i], date: DateTime(2026, 10, 13)));
    }
    await igor.db.insertTransaction(tx('in', 7000, type: TransactionType.income, date: DateTime(2026, 10, 1)));
    await syncAll([igor, partner]);

    final mine = await igor.db.getTransactions();
    final theirs = await partner.db.getTransactions();
    expect({for (final t in theirs) t.id: t.amount}, {for (final t in mine) t.id: t.amount});

    final b1 = computeBudget(now: now, transactions: mine, receivables: const [], personalFixed: const []);
    final b2 = computeBudget(now: now, transactions: theirs, receivables: const [], personalFixed: const []);
    expect(b2.weeklyBudget, b1.weeklyBudget);
    expect(b2.monthExpenses, closeTo(amounts.reduce((a, b) => a + b), 0.001));
  });

  test('the server never keeps an older version over a newer one', () async {
    await igor.db.insertTransaction(tx('z', 1));
    await igor.sync();
    clock.now = 99999;
    await partner.db.insertTransaction(tx('z', 2));
    await partner.sync();
    // Igor pushes a stale copy (e.g. marked dirty again after joining).
    await igor.db.markAllDirty();
    await igor.sync();
    expect(server.rows(home, 'transactions').single['amount'], 2);
    expect((await igor.db.getTransactions()).single.amount, 2);
  });
}
