import 'dart:convert';
import 'package:multisynk/sync/sync_engine.dart';

/// In-memory stand-in for the Supabase tables, enforcing the same rules as the SQL trigger:
/// an older `updated_at` never overwrites a newer one, and every accepted write gets a new `sync_seq`.
/// Rows go through JSON like the real API, and whole doubles come back as ints (100.0 → 100).
class FakeServer implements RemoteStore {
  int _seq = 0;
  int upserts = 0;
  final Map<String, Map<String, Map<String, dynamic>>> _tables = {};

  Map<String, Map<String, dynamic>> _table(String hid, String table) => _tables.putIfAbsent('$hid/$table', () => {});

  List<Map<String, dynamic>> rows(String hid, String table) => _table(hid, table).values.toList();

  List<Map<String, dynamic>> liveRows(String hid, String table) =>
      rows(hid, table).where((r) => r['deleted'] != true).toList();

  static Map<String, dynamic> _wire(Map<String, dynamic> m) =>
      (jsonDecode(jsonEncode(m)) as Map<String, dynamic>).map((k, v) => MapEntry(k, v is double && v == v.roundToDouble() ? v.toInt() : v));

  @override
  Future<void> upsert(String table, String pk, String householdId, List<Map<String, dynamic>> rows) async {
    upserts++;
    final t = _table(householdId, table);
    for (final incoming in rows) {
      final row = _wire(incoming);
      final id = row[pk] as String;
      final existing = t[id];
      if (existing != null && (row['updated_at'] as int) < (existing['updated_at'] as int)) continue;
      t[id] = {...row, 'household_id': householdId, 'sync_seq': ++_seq};
    }
  }

  @override
  Future<void> markDeleted(String table, String pk, String householdId, String id, int deletedAt) async {
    final t = _table(householdId, table);
    final existing = t[id];
    if (existing == null || deletedAt < (existing['updated_at'] as int)) return;
    t[id] = {...existing, 'deleted': true, 'updated_at': deletedAt, 'sync_seq': ++_seq};
  }

  @override
  Future<List<Map<String, dynamic>>> pull(String table, String householdId, int afterSeq, int limit) async {
    final list = _table(householdId, table).values.where((r) => (r['sync_seq'] as int) > afterSeq).toList()
      ..sort((a, b) => (a['sync_seq'] as int).compareTo(b['sync_seq'] as int));
    return list.take(limit).map(_wire).toList();
  }
}

class MemoryCursors implements CursorStore {
  final Map<String, int> values = {};
  @override
  Future<int> get(String key) async => values[key] ?? 0;
  @override
  Future<void> set(String key, int value) async => values[key] = value;
  @override
  Future<void> clear() async => values.clear();
}
