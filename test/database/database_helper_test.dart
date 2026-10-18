import 'package:flutter_test/flutter_test.dart';
import 'package:multisynk/database/database_helper.dart';
import 'package:multisynk/models/fiorino_entry.dart';
import 'package:multisynk/models/shopping_item.dart';
import 'package:multisynk/models/transaction.dart';
import 'package:multisynk/models/vehicle.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import '../support/test_db.dart';

Transaction tx(String id, double amount, {DateTime? date}) =>
    Transaction(id: id, description: id, amount: amount, type: TransactionType.expense, date: date ?? DateTime(2026, 10, 14));

/// The exact v8 schema shipped in the APK the user has installed today.
const _v8Schema = [
  'CREATE TABLE transactions(id TEXT PRIMARY KEY, description TEXT NOT NULL, amount REAL NOT NULL, type TEXT NOT NULL, date TEXT NOT NULL, category TEXT, vehicle_id TEXT, payment_method TEXT, card_id TEXT, installments INTEGER NOT NULL DEFAULT 1, installment_number INTEGER NOT NULL DEFAULT 1, installment_group_id TEXT)',
  'CREATE TABLE vehicles(id TEXT PRIMARY KEY, name TEXT NOT NULL, brand TEXT NOT NULL, model TEXT NOT NULL, color TEXT NOT NULL, plate TEXT, year INTEGER, notes TEXT)',
  'CREATE TABLE maintenance_items(id TEXT PRIMARY KEY, vehicle_id TEXT NOT NULL, title TEXT NOT NULL, description TEXT, priority TEXT NOT NULL, due_date TEXT, estimated_cost REAL, is_done INTEGER NOT NULL DEFAULT 0, FOREIGN KEY(vehicle_id) REFERENCES vehicles(id))',
  "CREATE TABLE tasks(id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT, priority TEXT NOT NULL DEFAULT 'none', ai_priority TEXT, ai_reason TEXT, category TEXT NOT NULL DEFAULT 'personal', created_at TEXT NOT NULL, due_date TEXT, is_done INTEGER NOT NULL DEFAULT 0)",
  "CREATE TABLE receivables(id TEXT PRIMARY KEY, description TEXT NOT NULL, expected_amount REAL NOT NULL, received_amount REAL, expected_date TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', is_recurring INTEGER NOT NULL DEFAULT 0)",
  'CREATE TABLE fiorino_entries(id TEXT PRIMARY KEY, amount REAL NOT NULL, date TEXT NOT NULL, notes TEXT, safety_percent REAL NOT NULL DEFAULT 0.10, maintenance_percent REAL NOT NULL DEFAULT 0.10, fuel_percent REAL NOT NULL DEFAULT 0.20)',
  'CREATE TABLE fiorino_config(key TEXT PRIMARY KEY, safety_percent REAL NOT NULL DEFAULT 0.10, maintenance_percent REAL NOT NULL DEFAULT 0.10, fuel_percent REAL NOT NULL DEFAULT 0.20)',
  'CREATE TABLE studio_entries(id TEXT PRIMARY KEY, amount REAL NOT NULL, type TEXT NOT NULL, description TEXT NOT NULL, category TEXT, date TEXT NOT NULL, notes TEXT, payment_method TEXT, card_id TEXT, installments INTEGER NOT NULL DEFAULT 1, installment_number INTEGER NOT NULL DEFAULT 1, installment_group_id TEXT)',
  'CREATE TABLE studio_config(key TEXT PRIMARY KEY, safety_percent REAL NOT NULL DEFAULT 0.10, savings_percent REAL NOT NULL DEFAULT 0.15)',
  "CREATE TABLE fixed_expenses(id TEXT PRIMARY KEY, description TEXT NOT NULL, amount REAL NOT NULL, category TEXT NOT NULL DEFAULT '', scope TEXT NOT NULL DEFAULT 'personal', is_active INTEGER NOT NULL DEFAULT 1, due_day INTEGER NOT NULL DEFAULT 10)",
  "CREATE TABLE payment_cards(id TEXT PRIMARY KEY, name TEXT NOT NULL, last_four TEXT, closing_day INTEGER NOT NULL DEFAULT 1, due_day INTEGER NOT NULL DEFAULT 10, color TEXT NOT NULL DEFAULT '#7C3AED')",
  "CREATE TABLE shopping_items(id TEXT PRIMARY KEY, description TEXT NOT NULL, quantity INTEGER NOT NULL DEFAULT 1, estimated_price REAL, category TEXT NOT NULL DEFAULT 'outro', is_purchased INTEGER NOT NULL DEFAULT 0, ai_priority TEXT, ai_reason TEXT, created_at TEXT NOT NULL)",
];

Future<Map<String, Object?>> rawRow(DatabaseHelper h, String table, String id, {String pk = 'id'}) async {
  final db = await h.database;
  final rows = await db.query(table, where: '$pk = ?', whereArgs: [id]);
  return rows.single;
}

void main() {
  group('fresh install (v9)', () {
    test('every synced table has sync columns; seeds are untouched (updated_at 0)', () async {
      final h = newTestDb('fresh', TestClock(5000));
      for (final spec in syncTables) {
        final cols = await h.columnsOf(spec.name);
        expect(cols, containsAll(['updated_at', 'dirty', spec.pk]), reason: spec.name);
      }
      expect(await h.columnsOf('sync_deletions'), containsAll(['table_name', 'row_id', 'deleted_at']));
      final meriva = await rawRow(h, 'vehicles', 'meriva-001');
      expect(meriva['updated_at'], 0);
      expect(meriva['dirty'], 1);
      expect((await h.getVehicles()).map((v) => v.id), containsAll(['meriva-001', 'fiorino-001']));
      await h.close();
    });
  });

  group('writes', () {
    test('insert stamps updated_at and marks dirty; markClean respects later edits', () async {
      final clock = TestClock(1000);
      final h = newTestDb('writes', clock);
      await h.insertTransaction(tx('a', 10));
      var row = await rawRow(h, 'transactions', 'a');
      expect(row['updated_at'], 1000);
      expect(row['dirty'], 1);

      await h.markClean('transactions', 'id', 'a', 1000);
      expect((await rawRow(h, 'transactions', 'a'))['dirty'], 0);

      clock.advance();
      await h.insertTransaction(tx('a', 20));
      await h.markClean('transactions', 'id', 'a', 1000); // stale stamp: must not clear
      row = await rawRow(h, 'transactions', 'a');
      expect(row['dirty'], 1);
      expect(row['amount'], 20.0);
      await h.close();
    });

    test('notifies after every local write and delete', () async {
      final h = newTestDb('notify', TestClock());
      var calls = 0;
      h.onLocalChange = () => calls++;
      await h.insertTransaction(tx('a', 1));
      await h.deleteTransaction('a');
      await h.saveFiorinoConfig(const FiorinoConfig(safetyPercent: 0.2));
      expect(calls, 3);
      await h.close();
    });

    test('delete records a tombstone; re-creating the row removes it', () async {
      final clock = TestClock(1000);
      final h = newTestDb('tomb', clock);
      await h.insertTransaction(tx('a', 10));
      clock.advance();
      await h.deleteTransaction('a');
      expect((await h.pendingDeletions()).map((d) => (d.table, d.id, d.deletedAt)), [('transactions', 'a', 2000)]);
      await h.deleteTransaction('missing'); // deleting nothing records nothing
      expect((await h.pendingDeletions()).length, 1);
      clock.advance();
      await h.insertTransaction(tx('a', 15));
      expect(await h.pendingDeletions(), isEmpty);
      await h.close();
    });

    test('clearing purchased items logs one tombstone per item and keeps pending ones', () async {
      final h = newTestDb('shop', TestClock());
      final now = DateTime(2026, 10, 1);
      await h.insertShoppingItem(ShoppingItem(id: 'p1', description: 'a', isPurchased: true, createdAt: now));
      await h.insertShoppingItem(ShoppingItem(id: 'p2', description: 'b', isPurchased: true, createdAt: now));
      await h.insertShoppingItem(ShoppingItem(id: 'open', description: 'c', createdAt: now));
      await h.clearPurchasedItems();
      expect((await h.getShoppingItems()).map((i) => i.id), ['open']);
      expect((await h.pendingDeletions()).map((d) => d.id).toSet(), {'p1', 'p2'});
      await h.close();
    });

    test('config rows use their key as primary key', () async {
      final h = newTestDb('cfg', TestClock());
      await h.saveFiorinoConfig(const FiorinoConfig(safetyPercent: 0.3, maintenancePercent: 0.1, fuelPercent: 0.1));
      await h.saveFiorinoConfig(const FiorinoConfig(safetyPercent: 0.25, maintenancePercent: 0.1, fuelPercent: 0.1));
      final db = await h.database;
      expect((await db.query('fiorino_config')).length, 1);
      expect((await h.getFiorinoConfig()).safetyPercent, 0.25);
      await h.close();
    });
  });

  group('upgrade from the installed v8', () {
    test('keeps all data, stamps real rows, leaves untouched seeds at 0, marks everything for upload', () async {
      sqfliteFfiInit();
      final path = tempDbPath('upgrade');
      final v8 = await databaseFactoryFfi.openDatabase(path, options: OpenDatabaseOptions(version: 8, onCreate: (db, _) async {
        for (final sql in _v8Schema) {
          await db.execute(sql);
        }
      }));
      await v8.insert('vehicles', {'id': 'meriva-001', 'name': 'Meriva', 'brand': 'Chevrolet', 'model': 'Meriva', 'color': 'Cinza Chumbo', 'plate': 'ABC1D23', 'year': null, 'notes': null});
      await v8.insert('vehicles', {'id': 'fiorino-001', 'name': 'Fiorino', 'brand': 'Fiat', 'model': 'Fiorino', 'color': 'Branca', 'plate': null, 'year': null, 'notes': null});
      await v8.insert('transactions', tx('old', 123.45).toMap());
      await v8.insert('fiorino_config', const FiorinoConfig(safetyPercent: 0.12).toMap());
      await v8.close();

      final h = DatabaseHelper.forTesting(factory: databaseFactoryFfi, path: path, clock: TestClock(77777).call);
      final txs = await h.getTransactions();
      expect(txs.single.amount, 123.45);
      expect((await rawRow(h, 'transactions', 'old'))['updated_at'], 77777);
      expect((await rawRow(h, 'transactions', 'old'))['dirty'], 1);
      expect((await rawRow(h, 'vehicles', 'meriva-001'))['updated_at'], 77777, reason: 'edited plate is real data');
      expect((await rawRow(h, 'vehicles', 'fiorino-001'))['updated_at'], 0, reason: 'untouched seed');
      expect((await h.getFiorinoConfig()).safetyPercent, 0.12);
      expect(await h.pendingDeletions(), isEmpty);
      final vehicles = await h.getVehicles();
      expect(vehicles.firstWhere((v) => v.id == 'meriva-001').plate, 'ABC1D23');
      await h.close();
    });
  });

  group('applyRemoteRows (last write wins)', () {
    Map<String, dynamic> remote(String id, double amount, int updatedAt, {bool deleted = false}) => {
          ...tx(id, amount).toMap(),
          'amount': amount == amount.roundToDouble() ? amount.toInt() : amount, // JSON style
          'updated_at': updatedAt,
          'deleted': deleted,
          'household_id': 'h1',
          'sync_seq': 1,
          'updated_by': 'u',
        };

    test('inserts new rows clean, ignores cloud-only columns', () async {
      final h = newTestDb('apply-new', TestClock());
      expect(await h.applyRemoteRows('transactions', 'id', [remote('r', 50, 900)]), 1);
      final row = await rawRow(h, 'transactions', 'r');
      expect(row['dirty'], 0);
      expect(row['updated_at'], 900);
      expect(row['amount'], 50.0);
      expect(row.containsKey('household_id'), isFalse);
      expect((await h.getTransactions()).single.amount, 50.0);
      await h.close();
    });

    test('newer remote replaces local; older or equal remote is ignored', () async {
      final h = newTestDb('apply-lww', TestClock(1000));
      await h.insertTransaction(tx('r', 10)); // local updated_at 1000
      expect(await h.applyRemoteRows('transactions', 'id', [remote('r', 99, 999)]), 0);
      expect(await h.applyRemoteRows('transactions', 'id', [remote('r', 99, 1000)]), 0);
      expect((await h.getTransactions()).single.amount, 10);
      expect(await h.applyRemoteRows('transactions', 'id', [remote('r', 77, 1001)]), 1);
      expect((await h.getTransactions()).single.amount, 77);
      expect((await rawRow(h, 'transactions', 'r'))['dirty'], 0);
      await h.close();
    });

    test('remote deletion removes local rows not edited afterwards', () async {
      final h = newTestDb('apply-del', TestClock(1000));
      await h.insertTransaction(tx('keep', 1)); // 1000
      await h.insertTransaction(tx('gone', 1)); // 1000
      expect(await h.applyRemoteRows('transactions', 'id', [
        remote('keep', 1, 999, deleted: true),
        remote('gone', 1, 1500, deleted: true),
        remote('never-had', 1, 1500, deleted: true),
      ]), 1);
      expect((await h.getTransactions()).map((t) => t.id), ['keep']);
      await h.close();
    });

    test('a pending local deletion beats an older remote version and loses to a newer one', () async {
      final clock = TestClock(1000);
      final h = newTestDb('apply-tomb', clock);
      await h.insertTransaction(tx('x', 1));
      clock.now = 2000;
      await h.deleteTransaction('x'); // tombstone at 2000
      expect(await h.applyRemoteRows('transactions', 'id', [remote('x', 5, 1500)]), 0);
      expect(await h.getTransactions(), isEmpty);
      expect((await h.pendingDeletions()).length, 1);
      expect(await h.applyRemoteRows('transactions', 'id', [remote('x', 5, 2500)]), 1);
      expect((await h.getTransactions()).single.amount, 5);
      expect(await h.pendingDeletions(), isEmpty);
      await h.close();
    });

    test('works for key-based config tables', () async {
      final h = newTestDb('apply-cfg', TestClock(1000));
      await h.applyRemoteRows('studio_config', 'key', [
        {'key': 'studio_config', 'safety_percent': 0.2, 'savings_percent': 0.3, 'updated_at': 5000, 'deleted': false},
      ]);
      final cfg = await h.getStudioConfig();
      expect(cfg.safetyPercent, 0.2);
      expect(cfg.savingsPercent, 0.3);
      await h.close();
    });

    test('maintenance items round-trip through the cloud format', () async {
      final h = newTestDb('apply-maint', TestClock(1000));
      final item = MaintenanceItem(id: 'm', vehicleId: 'meriva-001', title: 'Pneu', priority: MaintenancePriority.urgent, estimatedCost: 400, isDone: true);
      await h.applyRemoteRows('maintenance_items', 'id', [
        {...item.toMap(), 'estimated_cost': 400, 'updated_at': 3000, 'deleted': false},
      ]);
      final back = (await h.getMaintenanceItems('meriva-001')).single;
      expect(back.toMap(), item.toMap());
      await h.close();
    });
  });
}
