import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import '../models/map_utils.dart';
import '../models/transaction.dart';
import '../models/vehicle.dart';
import '../models/task.dart';
import '../models/receivable.dart';
import '../models/fiorino_entry.dart';
import '../models/studio_entry.dart';
import '../models/studio_config.dart';
import '../models/fixed_expense.dart';
import '../models/payment_card.dart';
import '../models/shopping_item.dart';

/// A local table that is mirrored to the cloud, with its primary-key column.
class SyncTableSpec {
  final String name;
  final String pk;
  const SyncTableSpec(this.name, [this.pk = 'id']);
}

const syncTables = <SyncTableSpec>[
  SyncTableSpec('transactions'),
  SyncTableSpec('vehicles'),
  SyncTableSpec('maintenance_items'),
  SyncTableSpec('tasks'),
  SyncTableSpec('receivables'),
  SyncTableSpec('fiorino_entries'),
  SyncTableSpec('fiorino_config', 'key'),
  SyncTableSpec('studio_entries'),
  SyncTableSpec('studio_config', 'key'),
  SyncTableSpec('fixed_expenses'),
  SyncTableSpec('payment_cards'),
  SyncTableSpec('shopping_items'),
];

SyncTableSpec syncSpecFor(String table) => syncTables.firstWhere((s) => s.name == table);

/// Columns used only by local sync bookkeeping (never sent to the cloud).
const localOnlyColumns = {'dirty'};

class PendingDeletion {
  final String table;
  final String id;
  final int deletedAt;
  const PendingDeletion(this.table, this.id, this.deletedAt);
}

const _seedVehicles = [
  {'id': 'meriva-001', 'name': 'Meriva', 'brand': 'Chevrolet', 'model': 'Meriva', 'color': 'Cinza Chumbo', 'plate': null, 'year': null, 'notes': null},
  {'id': 'fiorino-001', 'name': 'Fiorino', 'brand': 'Fiat', 'model': 'Fiorino', 'color': 'Branca', 'plate': null, 'year': null, 'notes': null},
];

class DatabaseHelper {
  static const schemaVersion = 9;

  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal()
      : _factory = null,
        _path = null,
        _clock = _systemClock;

  @visibleForTesting
  DatabaseHelper.forTesting({required DatabaseFactory factory, required String path, int Function()? clock})
      : _factory = factory,
        _path = path,
        _clock = clock ?? _systemClock;

  static int _systemClock() => DateTime.now().millisecondsSinceEpoch;

  final DatabaseFactory? _factory;
  final String? _path;
  final int Function() _clock;

  /// Invoked after every local write (used to schedule a cloud sync).
  void Function()? onLocalChange;

  Database? _db;
  final Map<String, Set<String>> _columnsCache = {};

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  @visibleForTesting
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _initDB() async {
    final options = OpenDatabaseOptions(version: schemaVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
    if (_factory != null) return _factory.openDatabase(_path!, options: options);
    if (kIsWeb) return databaseFactoryFfiWeb.openDatabase('multisynk.db', options: options);
    return databaseFactory.openDatabase(join(await getDatabasesPath(), 'multisynk.db'), options: options);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fiorino_entries(
          id TEXT PRIMARY KEY,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          notes TEXT,
          safety_percent REAL NOT NULL DEFAULT 0.10,
          maintenance_percent REAL NOT NULL DEFAULT 0.10
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fiorino_config(
          key TEXT PRIMARY KEY,
          safety_percent REAL NOT NULL DEFAULT 0.10,
          maintenance_percent REAL NOT NULL DEFAULT 0.10
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS studio_entries(
          id TEXT PRIMARY KEY,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          description TEXT NOT NULL,
          category TEXT,
          date TEXT NOT NULL,
          notes TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE fiorino_entries ADD COLUMN fuel_percent REAL NOT NULL DEFAULT 0.20');
      await db.execute('ALTER TABLE fiorino_config  ADD COLUMN fuel_percent REAL NOT NULL DEFAULT 0.20');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS studio_config(
          key TEXT PRIMARY KEY,
          safety_percent  REAL NOT NULL DEFAULT 0.10,
          savings_percent REAL NOT NULL DEFAULT 0.15
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fixed_expenses(
          id TEXT PRIMARY KEY,
          description TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL DEFAULT '',
          scope TEXT NOT NULL DEFAULT 'personal',
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payment_cards(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          last_four TEXT,
          closing_day INTEGER NOT NULL DEFAULT 1,
          due_day INTEGER NOT NULL DEFAULT 10,
          color TEXT NOT NULL DEFAULT '#7C3AED'
        )
      ''');
      for (final table in ['transactions', 'studio_entries']) {
        await db.execute('ALTER TABLE $table ADD COLUMN payment_method TEXT');
        await db.execute('ALTER TABLE $table ADD COLUMN card_id TEXT');
        await db.execute('ALTER TABLE $table ADD COLUMN installments INTEGER NOT NULL DEFAULT 1');
        await db.execute('ALTER TABLE $table ADD COLUMN installment_number INTEGER NOT NULL DEFAULT 1');
        await db.execute('ALTER TABLE $table ADD COLUMN installment_group_id TEXT');
      }
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shopping_items(
          id TEXT PRIMARY KEY,
          description TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1,
          estimated_price REAL,
          category TEXT NOT NULL DEFAULT 'outro',
          is_purchased INTEGER NOT NULL DEFAULT 0,
          ai_priority TEXT,
          ai_reason TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 8) {
      if (!await _hasColumn(db, 'fixed_expenses', 'due_day')) {
        await db.execute('ALTER TABLE fixed_expenses ADD COLUMN due_day INTEGER NOT NULL DEFAULT 10');
      }
    }
    if (oldVersion < 9) {
      await _addSyncSchema(db, stampExisting: true);
    }
  }

  Future<bool> _hasColumn(DatabaseExecutor db, String table, String column) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.any((c) => c['name'] == column);
  }

  /// v9: per-row edit time + pending-upload flag on every synced table, and a deletion log.
  Future<void> _addSyncSchema(Database db, {required bool stampExisting}) async {
    final now = _clock();
    for (final spec in syncTables) {
      if (!await _hasColumn(db, spec.name, 'updated_at')) {
        await db.execute('ALTER TABLE ${spec.name} ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
      }
      if (!await _hasColumn(db, spec.name, 'dirty')) {
        await db.execute('ALTER TABLE ${spec.name} ADD COLUMN dirty INTEGER NOT NULL DEFAULT 1');
      }
      if (stampExisting) {
        // Existing rows are real user data: stamp them now so they win over untouched copies
        // on other devices. Rows still equal to the built-in seed stay at 0 so they never
        // overwrite a vehicle someone actually edited.
        await db.execute('UPDATE ${spec.name} SET updated_at = ? WHERE updated_at = 0', [now]);
      }
    }
    if (stampExisting) {
      for (final seed in _seedVehicles) {
        final rows = await db.query('vehicles', where: 'id = ?', whereArgs: [seed['id']]);
        if (rows.isNotEmpty && seed.keys.every((k) => rows.first[k] == seed[k])) {
          await db.update('vehicles', {'updated_at': 0}, where: 'id = ?', whereArgs: [seed['id']]);
        }
      }
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_deletions(
        table_name TEXT NOT NULL,
        row_id TEXT NOT NULL,
        deleted_at INTEGER NOT NULL,
        PRIMARY KEY (table_name, row_id)
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions(
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        category TEXT,
        vehicle_id TEXT,
        payment_method TEXT,
        card_id TEXT,
        installments INTEGER NOT NULL DEFAULT 1,
        installment_number INTEGER NOT NULL DEFAULT 1,
        installment_group_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE vehicles(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        color TEXT NOT NULL,
        plate TEXT,
        year INTEGER,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE maintenance_items(
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        priority TEXT NOT NULL,
        due_date TEXT,
        estimated_cost REAL,
        is_done INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(vehicle_id) REFERENCES vehicles(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        priority TEXT NOT NULL DEFAULT 'none',
        ai_priority TEXT,
        ai_reason TEXT,
        category TEXT NOT NULL DEFAULT 'personal',
        created_at TEXT NOT NULL,
        due_date TEXT,
        is_done INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE receivables(
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        expected_amount REAL NOT NULL,
        received_amount REAL,
        expected_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        is_recurring INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE fiorino_entries(
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        safety_percent REAL NOT NULL DEFAULT 0.10,
        maintenance_percent REAL NOT NULL DEFAULT 0.10,
        fuel_percent REAL NOT NULL DEFAULT 0.20
      )
    ''');

    await db.execute('''
      CREATE TABLE fiorino_config(
        key TEXT PRIMARY KEY,
        safety_percent REAL NOT NULL DEFAULT 0.10,
        maintenance_percent REAL NOT NULL DEFAULT 0.10,
        fuel_percent REAL NOT NULL DEFAULT 0.20
      )
    ''');

    await db.execute('''
      CREATE TABLE studio_entries(
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT,
        date TEXT NOT NULL,
        notes TEXT,
        payment_method TEXT,
        card_id TEXT,
        installments INTEGER NOT NULL DEFAULT 1,
        installment_number INTEGER NOT NULL DEFAULT 1,
        installment_group_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE studio_config(
        key TEXT PRIMARY KEY,
        safety_percent  REAL NOT NULL DEFAULT 0.10,
        savings_percent REAL NOT NULL DEFAULT 0.15
      )
    ''');

    await db.execute('''
      CREATE TABLE fixed_expenses(
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL DEFAULT '',
        scope TEXT NOT NULL DEFAULT 'personal',
        is_active INTEGER NOT NULL DEFAULT 1,
        due_day INTEGER NOT NULL DEFAULT 10
      )
    ''');

    await db.execute('''
      CREATE TABLE payment_cards(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        last_four TEXT,
        closing_day INTEGER NOT NULL DEFAULT 1,
        due_day INTEGER NOT NULL DEFAULT 10,
        color TEXT NOT NULL DEFAULT '#7C3AED'
      )
    ''');

    await db.execute('''
      CREATE TABLE shopping_items(
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        estimated_price REAL,
        category TEXT NOT NULL DEFAULT 'outro',
        is_purchased INTEGER NOT NULL DEFAULT 0,
        ai_priority TEXT,
        ai_reason TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await _addSyncSchema(db, stampExisting: false);

    // Seed rows keep updated_at = 0 so any real edit (local or from the household) wins.
    for (final seed in _seedVehicles) {
      await db.insert('vehicles', seed);
    }
  }

  // ── Generic write helpers (stamp + dirty + deletion log) ────────────────────

  Future<void> _put(String table, Map<String, dynamic> row, {String pk = 'id'}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(table, {...row, 'updated_at': _clock(), 'dirty': 1},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('sync_deletions', where: 'table_name = ? AND row_id = ?', whereArgs: [table, row[pk]]);
    });
    onLocalChange?.call();
  }

  Future<void> _remove(String table, List<String> ids, {String pk = 'id'}) async {
    if (ids.isEmpty) return;
    final db = await database;
    final now = _clock();
    await db.transaction((txn) async {
      for (final id in ids) {
        final n = await txn.delete(table, where: '$pk = ?', whereArgs: [id]);
        if (n > 0) {
          await txn.insert('sync_deletions', {'table_name': table, 'row_id': id, 'deleted_at': now},
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
    onLocalChange?.call();
  }

  // ── Transactions ────────────────────────────────────────────────────────────
  Future<void> insertTransaction(Transaction t) => _put('transactions', t.toMap());

  Future<List<Transaction>> getTransactions({String? vehicleId}) async {
    final db = await database;
    final maps = vehicleId != null
        ? await db.query('transactions', where: 'vehicle_id = ?', whereArgs: [vehicleId], orderBy: 'date DESC')
        : await db.query('transactions', orderBy: 'date DESC');
    return maps.map(Transaction.fromMap).toList();
  }

  Future<void> deleteTransaction(String id) => _remove('transactions', [id]);

  // ── Vehicles ────────────────────────────────────────────────────────────────
  Future<List<Vehicle>> getVehicles() async {
    final db = await database;
    final vehicleMaps = await db.query('vehicles');
    final vehicles = <Vehicle>[];
    for (final vMap in vehicleMaps) {
      final id = vMap['id'] as String;
      final items = await getMaintenanceItems(id);
      final totalMap = await db.rawQuery(
        'SELECT SUM(amount) as total FROM transactions WHERE vehicle_id = ? AND type = ?',
        [id, 'expense'],
      );
      final total = asDouble(totalMap.first['total']);
      vehicles.add(Vehicle.fromMap(vMap, maintenanceItems: items, totalSpent: total));
    }
    return vehicles;
  }

  Future<void> insertVehicle(Vehicle v) => _put('vehicles', v.toMap());

  Future<void> updateVehicle(Vehicle v) => _put('vehicles', v.toMap());

  // ── Maintenance ─────────────────────────────────────────────────────────────
  Future<List<MaintenanceItem>> getMaintenanceItems(String vehicleId) async {
    final db = await database;
    final maps = await db.query(
      'maintenance_items',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'is_done ASC, priority DESC',
    );
    return maps.map(MaintenanceItem.fromMap).toList();
  }

  Future<void> insertMaintenanceItem(MaintenanceItem item) => _put('maintenance_items', item.toMap());

  Future<void> updateMaintenanceItem(MaintenanceItem item) => _put('maintenance_items', item.toMap());

  Future<void> deleteMaintenanceItem(String id) => _remove('maintenance_items', [id]);

  // ── Tasks ───────────────────────────────────────────────────────────────────
  Future<List<Task>> getTasks({bool includeDone = false}) async {
    final db = await database;
    final maps = includeDone
        ? await db.query('tasks', orderBy: 'is_done ASC, created_at DESC')
        : await db.query('tasks', where: 'is_done = 0', orderBy: 'created_at DESC');
    return maps.map(Task.fromMap).toList();
  }

  Future<void> insertTask(Task task) => _put('tasks', task.toMap());

  Future<void> updateTask(Task task) => _put('tasks', task.toMap());

  Future<void> deleteTask(String id) => _remove('tasks', [id]);

  // ── Receivables ─────────────────────────────────────────────────────────────
  Future<List<Receivable>> getReceivables({bool pendingOnly = false}) async {
    final db = await database;
    final maps = pendingOnly
        ? await db.query('receivables', where: 'status != ?', whereArgs: ['received'], orderBy: 'expected_date ASC')
        : await db.query('receivables', orderBy: 'expected_date ASC');
    return maps.map(Receivable.fromMap).toList();
  }

  Future<void> insertReceivable(Receivable r) => _put('receivables', r.toMap());

  Future<void> updateReceivable(Receivable r) => _put('receivables', r.toMap());

  Future<void> deleteReceivable(String id) => _remove('receivables', [id]);

  // ── Fiorino ─────────────────────────────────────────────────────────────────
  Future<FiorinoConfig> getFiorinoConfig() async {
    final db = await database;
    final maps = await db.query('fiorino_config', where: 'key = ?', whereArgs: ['fiorino_config']);
    if (maps.isEmpty) return const FiorinoConfig();
    return FiorinoConfig.fromMap(maps.first);
  }

  Future<void> saveFiorinoConfig(FiorinoConfig config) => _put('fiorino_config', config.toMap(), pk: 'key');

  Future<void> insertFiorinoEntry(FiorinoEntry entry) => _put('fiorino_entries', entry.toMap());

  Future<List<FiorinoEntry>> getFiorinoEntries({DateTime? from, DateTime? to}) async {
    final db = await database;
    String? where;
    List<Object?>? args;
    if (from != null && to != null) {
      where = 'date >= ? AND date <= ?';
      args = [from.toIso8601String(), to.toIso8601String()];
    } else if (from != null) {
      where = 'date >= ?';
      args = [from.toIso8601String()];
    }
    final maps = await db.query('fiorino_entries', where: where, whereArgs: args, orderBy: 'date DESC');
    return maps.map(FiorinoEntry.fromMap).toList();
  }

  Future<void> deleteFiorinoEntry(String id) => _remove('fiorino_entries', [id]);

  // ── Studio ──────────────────────────────────────────────────────────────────
  Future<void> insertStudioEntry(StudioEntry entry) => _put('studio_entries', entry.toMap());

  Future<List<StudioEntry>> getStudioEntries({String? type}) async {
    final db = await database;
    final maps = type != null
        ? await db.query('studio_entries', where: 'type = ?', whereArgs: [type], orderBy: 'date DESC')
        : await db.query('studio_entries', orderBy: 'date DESC');
    return maps.map(StudioEntry.fromMap).toList();
  }

  Future<void> deleteStudioEntry(String id) => _remove('studio_entries', [id]);

  Future<StudioConfig> getStudioConfig() async {
    final db = await database;
    final maps = await db.query('studio_config', where: 'key = ?', whereArgs: ['studio_config']);
    if (maps.isEmpty) return const StudioConfig();
    return StudioConfig.fromMap(maps.first);
  }

  Future<void> saveStudioConfig(StudioConfig config) => _put('studio_config', config.toMap(), pk: 'key');

  // ── Fixed expenses ──────────────────────────────────────────────────────────
  Future<List<FixedExpense>> getFixedExpenses() async {
    final db = await database;
    final maps = await db.query('fixed_expenses', orderBy: 'scope ASC, description ASC');
    return maps.map(FixedExpense.fromMap).toList();
  }

  Future<void> insertFixedExpense(FixedExpense e) => _put('fixed_expenses', e.toMap());

  Future<void> updateFixedExpense(FixedExpense e) => _put('fixed_expenses', e.toMap());

  Future<void> deleteFixedExpense(String id) => _remove('fixed_expenses', [id]);

  // ── Payment cards ───────────────────────────────────────────────────────────
  Future<List<PaymentCard>> getPaymentCards() async {
    final db = await database;
    final maps = await db.query('payment_cards', orderBy: 'name ASC');
    return maps.map(PaymentCard.fromMap).toList();
  }

  Future<void> insertPaymentCard(PaymentCard card) => _put('payment_cards', card.toMap());

  Future<void> updatePaymentCard(PaymentCard card) => _put('payment_cards', card.toMap());

  Future<void> deletePaymentCard(String id) => _remove('payment_cards', [id]);

  // ── Shopping items ──────────────────────────────────────────────────────────
  Future<List<ShoppingItem>> getShoppingItems() async {
    final db = await database;
    final maps = await db.query('shopping_items', orderBy: 'is_purchased ASC, created_at DESC');
    return maps.map(ShoppingItem.fromMap).toList();
  }

  Future<void> insertShoppingItem(ShoppingItem item) => _put('shopping_items', item.toMap());

  Future<void> updateShoppingItem(ShoppingItem item) => _put('shopping_items', item.toMap());

  Future<void> deleteShoppingItem(String id) => _remove('shopping_items', [id]);

  Future<void> clearPurchasedItems() async {
    final db = await database;
    final rows = await db.query('shopping_items', columns: ['id'], where: 'is_purchased = 1');
    await _remove('shopping_items', [for (final r in rows) r['id'] as String]);
  }

  // ── Sync API ────────────────────────────────────────────────────────────────

  Future<Set<String>> columnsOf(String table) async {
    final cached = _columnsCache[table];
    if (cached != null) return cached;
    final db = await database;
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return _columnsCache[table] = {for (final c in info) c['name'] as String};
  }

  /// Rows changed locally and not yet confirmed by the cloud.
  Future<List<Map<String, dynamic>>> dirtyRows(String table) async {
    final db = await database;
    final rows = await db.query(table, where: 'dirty = 1');
    return [for (final r in rows) Map<String, dynamic>.of(r)];
  }

  /// Clears the pending flag only if the row was not edited again after it was read for upload.
  Future<void> markClean(String table, String pk, Object id, int updatedAt) async {
    final db = await database;
    await db.update(table, {'dirty': 0}, where: '$pk = ? AND updated_at = ?', whereArgs: [id, updatedAt]);
  }

  Future<List<PendingDeletion>> pendingDeletions() async {
    final db = await database;
    final rows = await db.query('sync_deletions', orderBy: 'deleted_at ASC');
    return [
      for (final r in rows) PendingDeletion(r['table_name'] as String, r['row_id'] as String, asInt(r['deleted_at']))
    ];
  }

  Future<void> clearDeletion(PendingDeletion d) async {
    final db = await database;
    await db.delete('sync_deletions',
        where: 'table_name = ? AND row_id = ? AND deleted_at = ?', whereArgs: [d.table, d.id, d.deletedAt]);
  }

  /// Marks every row for upload (used when the device joins a different household).
  Future<void> markAllDirty() async {
    final db = await database;
    for (final spec in syncTables) {
      await db.update(spec.name, {'dirty': 1});
    }
  }

  /// Applies rows pulled from the cloud with last-write-wins on `updated_at`.
  /// Returns how many local rows actually changed.
  Future<int> applyRemoteRows(String table, String pk, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return 0;
    final columns = await columnsOf(table);
    final db = await database;
    var changed = 0;
    await db.transaction((txn) async {
      for (final remote in rows) {
        final id = remote[pk] as String;
        final remoteUpdated = asInt(remote['updated_at']);
        final local = await txn.query(table, columns: ['updated_at'], where: '$pk = ?', whereArgs: [id]);
        final localUpdated = local.isEmpty ? null : asInt(local.first['updated_at']);
        final tomb = await txn.query('sync_deletions',
            columns: ['deleted_at'], where: 'table_name = ? AND row_id = ?', whereArgs: [table, id]);
        final deletedAt = tomb.isEmpty ? null : asInt(tomb.first['deleted_at']);

        if (asBool(remote['deleted'])) {
          if (localUpdated != null && localUpdated <= remoteUpdated) {
            await txn.delete(table, where: '$pk = ?', whereArgs: [id]);
            changed++;
          }
          if (deletedAt != null && deletedAt <= remoteUpdated) {
            await txn.delete('sync_deletions', where: 'table_name = ? AND row_id = ?', whereArgs: [table, id]);
          }
          continue;
        }

        if (deletedAt != null && deletedAt > remoteUpdated) continue; // our newer deletion goes up next
        if (localUpdated != null && localUpdated >= remoteUpdated) continue; // same or newer local version

        final row = <String, dynamic>{
          for (final e in remote.entries)
            if (columns.contains(e.key) && !localOnlyColumns.contains(e.key)) e.key: e.value,
          'updated_at': remoteUpdated,
          'dirty': 0,
        };
        await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
        if (deletedAt != null) {
          await txn.delete('sync_deletions', where: 'table_name = ? AND row_id = ?', whereArgs: [table, id]);
        }
        changed++;
      }
    });
    return changed;
  }
}
