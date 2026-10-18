import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
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

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
    final path = kIsWeb ? 'multisynk.db' : join(await getDatabasesPath(), 'multisynk.db');
    return openDatabase(path, version: 8, onCreate: _onCreate, onUpgrade: _onUpgrade);
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
      // Add due_day column to fixed_expenses (was missing since v5)
      try {
        await db.execute('ALTER TABLE fixed_expenses ADD COLUMN due_day INTEGER NOT NULL DEFAULT 10');
      } catch (_) {}
    }
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

    await _insertSeedData(db);
  }

  Future<void> _insertSeedData(Database db) async {
    await db.insert('vehicles', {
      'id': 'meriva-001',
      'name': 'Meriva',
      'brand': 'Chevrolet',
      'model': 'Meriva',
      'color': 'Cinza Chumbo',
      'plate': null,
      'year': null,
      'notes': null,
    });

    await db.insert('vehicles', {
      'id': 'fiorino-001',
      'name': 'Fiorino',
      'brand': 'Fiat',
      'model': 'Fiorino',
      'color': 'Branca',
      'plate': null,
      'year': null,
      'notes': null,
    });
  }

  // Transactions
  Future<void> insertTransaction(Transaction t) async {
    final db = await database;
    await db.insert('transactions', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Transaction>> getTransactions({String? vehicleId}) async {
    final db = await database;
    final maps = vehicleId != null
        ? await db.query('transactions', where: 'vehicle_id = ?', whereArgs: [vehicleId], orderBy: 'date DESC')
        : await db.query('transactions', orderBy: 'date DESC');
    return maps.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> getWeekTransactions() async {
    final db = await database;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final maps = await db.query(
      'transactions',
      where: 'date >= ?',
      whereArgs: [weekAgo.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map(Transaction.fromMap).toList();
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Vehicles
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
      final total = (totalMap.first['total'] as num?)?.toDouble() ?? 0;
      vehicles.add(Vehicle.fromMap(vMap, maintenanceItems: items, totalSpent: total));
    }
    return vehicles;
  }

  Future<void> insertVehicle(Vehicle v) async {
    final db = await database;
    await db.insert('vehicles', v.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateVehicle(Vehicle v) async {
    final db = await database;
    await db.update('vehicles', v.toMap(), where: 'id = ?', whereArgs: [v.id]);
  }

  // Maintenance
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

  Future<void> insertMaintenanceItem(MaintenanceItem item) async {
    final db = await database;
    await db.insert('maintenance_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMaintenanceItem(MaintenanceItem item) async {
    final db = await database;
    await db.update('maintenance_items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteMaintenanceItem(String id) async {
    final db = await database;
    await db.delete('maintenance_items', where: 'id = ?', whereArgs: [id]);
  }

  // Tasks
  Future<List<Task>> getTasks({bool includeDone = false}) async {
    final db = await database;
    final maps = includeDone
        ? await db.query('tasks', orderBy: 'is_done ASC, created_at DESC')
        : await db.query('tasks', where: 'is_done = 0', orderBy: 'created_at DESC');
    return maps.map(Task.fromMap).toList();
  }

  Future<void> insertTask(Task task) async {
    final db = await database;
    await db.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // Receivables
  Future<List<Receivable>> getReceivables({bool pendingOnly = false}) async {
    final db = await database;
    final maps = pendingOnly
        ? await db.query('receivables', where: 'status != ?', whereArgs: ['received'], orderBy: 'expected_date ASC')
        : await db.query('receivables', orderBy: 'expected_date ASC');
    return maps.map(Receivable.fromMap).toList();
  }

  Future<void> insertReceivable(Receivable r) async {
    final db = await database;
    await db.insert('receivables', r.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateReceivable(Receivable r) async {
    final db = await database;
    await db.update('receivables', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> deleteReceivable(String id) async {
    final db = await database;
    await db.delete('receivables', where: 'id = ?', whereArgs: [id]);
  }

  // Fiorino entries
  Future<FiorinoConfig> getFiorinoConfig() async {
    final db = await database;
    final maps = await db.query('fiorino_config', where: 'key = ?', whereArgs: ['fiorino_config']);
    if (maps.isEmpty) return const FiorinoConfig();
    return FiorinoConfig.fromMap(maps.first);
  }

  Future<void> saveFiorinoConfig(FiorinoConfig config) async {
    final db = await database;
    await db.insert('fiorino_config', config.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertFiorinoEntry(FiorinoEntry entry) async {
    final db = await database;
    await db.insert('fiorino_entries', entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

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

  Future<void> deleteFiorinoEntry(String id) async {
    final db = await database;
    await db.delete('fiorino_entries', where: 'id = ?', whereArgs: [id]);
  }

  // Studio entries
  Future<void> insertStudioEntry(StudioEntry entry) async {
    final db = await database;
    await db.insert('studio_entries', entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<StudioEntry>> getStudioEntries({String? type}) async {
    final db = await database;
    final maps = type != null
        ? await db.query('studio_entries', where: 'type = ?', whereArgs: [type], orderBy: 'date DESC')
        : await db.query('studio_entries', orderBy: 'date DESC');
    return maps.map(StudioEntry.fromMap).toList();
  }

  Future<void> deleteStudioEntry(String id) async {
    final db = await database;
    await db.delete('studio_entries', where: 'id = ?', whereArgs: [id]);
  }

  // Studio config
  Future<StudioConfig> getStudioConfig() async {
    final db = await database;
    final maps = await db.query('studio_config', where: 'key = ?', whereArgs: ['studio_config']);
    if (maps.isEmpty) return const StudioConfig();
    return StudioConfig.fromMap(maps.first);
  }

  Future<void> saveStudioConfig(StudioConfig config) async {
    final db = await database;
    await db.insert('studio_config', config.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Fixed expenses
  Future<List<FixedExpense>> getFixedExpenses() async {
    final db = await database;
    final maps = await db.query('fixed_expenses', orderBy: 'scope ASC, description ASC');
    return maps.map(FixedExpense.fromMap).toList();
  }

  Future<void> insertFixedExpense(FixedExpense e) async {
    final db = await database;
    await db.insert('fixed_expenses', e.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateFixedExpense(FixedExpense e) async {
    final db = await database;
    await db.update('fixed_expenses', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> deleteFixedExpense(String id) async {
    final db = await database;
    await db.delete('fixed_expenses', where: 'id = ?', whereArgs: [id]);
  }

  // Payment cards
  Future<List<PaymentCard>> getPaymentCards() async {
    final db = await database;
    final maps = await db.query('payment_cards', orderBy: 'name ASC');
    return maps.map(PaymentCard.fromMap).toList();
  }

  Future<void> insertPaymentCard(PaymentCard card) async {
    final db = await database;
    await db.insert('payment_cards', card.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updatePaymentCard(PaymentCard card) async {
    final db = await database;
    await db.update('payment_cards', card.toMap(), where: 'id = ?', whereArgs: [card.id]);
  }

  Future<void> deletePaymentCard(String id) async {
    final db = await database;
    await db.delete('payment_cards', where: 'id = ?', whereArgs: [id]);
  }

  // Shopping items
  Future<List<ShoppingItem>> getShoppingItems() async {
    final db = await database;
    final maps = await db.query('shopping_items', orderBy: 'is_purchased ASC, created_at DESC');
    return maps.map(ShoppingItem.fromMap).toList();
  }

  Future<void> insertShoppingItem(ShoppingItem item) async {
    final db = await database;
    await db.insert('shopping_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateShoppingItem(ShoppingItem item) async {
    final db = await database;
    await db.update('shopping_items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteShoppingItem(String id) async {
    final db = await database;
    await db.delete('shopping_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearPurchasedItems() async {
    final db = await database;
    await db.delete('shopping_items', where: 'is_purchased = ?', whereArgs: [1]);
  }
}
