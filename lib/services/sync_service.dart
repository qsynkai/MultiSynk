import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'connectivity_service.dart';
import '../database/database_helper.dart';

/// Sincroniza dados do SQLite local com o Supabase.
/// - SQLite é a fonte primária (funciona 100% offline)
/// - Supabase recebe upsert quando há rede + usuário autenticado
/// - Se offline, marca pendente e sincroniza quando reconectar
class SyncService {
  static final _db = DatabaseHelper.instance;
  static const _pendingKey = 'sync_pending';

  static Future<void> syncAll({bool silent = false}) async {
    if (!SupabaseService.isSignedIn) return;

    final online = await ConnectivityService.isOnline();
    if (!online) {
      await _markPending();
      return;
    }

    try {
      await Future.wait([
        _syncTransactions(),
        _syncReceivables(),
        _syncFixedExpenses(),
        _syncPaymentCards(),
        _syncTasks(),
        _syncShoppingItems(),
        _syncVehicles(),
        _syncFiorinoEntries(),
        _syncStudioEntries(),
        _syncConfigs(),
      ]);
      await _clearPending();
    } catch (_) {
      await _markPending();
    }
  }

  static Future<bool> hasPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingKey) ?? false;
  }

  static Future<void> _markPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, true);
  }

  static Future<void> _clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, false);
  }

  static String get _uid => SupabaseService.client.auth.currentUser!.id;

  static Future<void> _upsert(String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await SupabaseService.client.from(table).upsert(
      rows.map((r) => {...r, 'user_id': _uid}).toList(),
      onConflict: 'id',
    );
  }

  static Future<void> _syncTransactions() async {
    final rows = await _db.getTransactions();
    await _upsert('transactions', rows.map((t) => t.toMap()).toList());
  }

  static Future<void> _syncReceivables() async {
    final rows = await _db.getReceivables();
    await _upsert('receivables', rows.map((r) => r.toMap()).toList());
  }

  static Future<void> _syncFixedExpenses() async {
    final rows = await _db.getFixedExpenses();
    await _upsert('fixed_expenses', rows.map((f) => f.toMap()).toList());
  }

  static Future<void> _syncPaymentCards() async {
    final rows = await _db.getPaymentCards();
    await _upsert('payment_cards', rows.map((c) => c.toMap()).toList());
  }

  static Future<void> _syncTasks() async {
    final rows = await _db.getTasks(includeDone: true);
    await _upsert('tasks', rows.map((t) => t.toMap()).toList());
  }

  static Future<void> _syncShoppingItems() async {
    final rows = await _db.getShoppingItems();
    await _upsert('shopping_items', rows.map((s) => s.toMap()).toList());
  }

  static Future<void> _syncVehicles() async {
    final vehicles = await _db.getVehicles();
    await _upsert('vehicles', vehicles.map((v) => v.toMap()).toList());

    final allMaintenance = <Map<String, dynamic>>[];
    for (final v in vehicles) {
      final items = await _db.getMaintenanceItems(v.id);
      allMaintenance.addAll(items.map((m) => m.toMap()));
    }
    await _upsert('maintenance_items', allMaintenance);
  }

  static Future<void> _syncFiorinoEntries() async {
    final rows = await _db.getFiorinoEntries();
    await _upsert('fiorino_entries', rows.map((f) => f.toMap()).toList());
  }

  static Future<void> _syncStudioEntries() async {
    final rows = await _db.getStudioEntries();
    await _upsert('studio_entries', rows.map((s) => s.toMap()).toList());
  }

  static Future<void> _syncConfigs() async {
    final uid = _uid;
    final fCfg = await _db.getFiorinoConfig();
    await SupabaseService.client.from('fiorino_config').upsert(
      {...fCfg.toMap(), 'key': 'default', 'user_id': uid},
      onConflict: 'key,user_id',
    );
    final sCfg = await _db.getStudioConfig();
    await SupabaseService.client.from('studio_config').upsert(
      {...sCfg.toMap(), 'key': 'default', 'user_id': uid},
      onConflict: 'key,user_id',
    );
  }
}
