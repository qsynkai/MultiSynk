import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sync_engine.dart';

class SupabaseRemoteStore implements RemoteStore {
  SupabaseRemoteStore(this.client);

  final SupabaseClient client;

  @override
  Future<void> upsert(String table, String pk, String householdId, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await client.from(table).upsert(
      [for (final r in rows) {...r, 'household_id': householdId}],
      onConflict: 'household_id,$pk',
    );
  }

  @override
  Future<void> markDeleted(String table, String pk, String householdId, String id, int deletedAt) async {
    await client
        .from(table)
        .update({'deleted': true, 'updated_at': deletedAt})
        .eq('household_id', householdId)
        .eq(pk, id);
  }

  @override
  Future<List<Map<String, dynamic>>> pull(String table, String householdId, int afterSeq, int limit) async {
    final rows = await client
        .from(table)
        .select()
        .eq('household_id', householdId)
        .gt('sync_seq', afterSeq)
        .order('sync_seq', ascending: true)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }
}

class PrefsCursorStore implements CursorStore {
  static const _prefix = 'sync_cursor:';

  @override
  Future<int> get(String key) async => (await SharedPreferences.getInstance()).getInt('$_prefix$key') ?? 0;

  @override
  Future<void> set(String key, int value) async =>
      (await SharedPreferences.getInstance()).setInt('$_prefix$key', value);

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await prefs.remove(k);
    }
  }
}
