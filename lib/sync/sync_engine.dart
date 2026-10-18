import 'dart:math' as math;
import '../database/database_helper.dart';
import '../models/map_utils.dart';

/// Cloud side of the sync. The server enforces last-write-wins on `updated_at`
/// and stamps every accepted write with an increasing `sync_seq`.
abstract class RemoteStore {
  Future<void> upsert(String table, String pk, String householdId, List<Map<String, dynamic>> rows);
  Future<void> markDeleted(String table, String pk, String householdId, String id, int deletedAt);

  /// Rows of [table] in the household with `sync_seq > afterSeq`, ascending by `sync_seq`.
  Future<List<Map<String, dynamic>>> pull(String table, String householdId, int afterSeq, int limit);
}

abstract class CursorStore {
  Future<int> get(String key);
  Future<void> set(String key, int value);
  Future<void> clear();
}

class SyncReport {
  int pushedRows = 0;
  int pushedDeletions = 0;
  int pulledChanges = 0;

  @override
  String toString() => 'pushed=$pushedRows deleted=$pushedDeletions pulled=$pulledChanges';
}

class SyncEngine {
  SyncEngine(this.db, this.remote, this.cursors);

  final DatabaseHelper db;
  final RemoteStore remote;
  final CursorStore cursors;

  static const pushBatch = 500;
  static const pageSize = 500;

  /// Re-reads a window of recent sequence numbers on every pull. A write that took a sequence
  /// number but committed after a later one was already read would otherwise be skipped forever.
  /// Re-applying rows is harmless: last-write-wins makes it a no-op.
  static const lookback = 200;

  Future<SyncReport> run(String householdId) async {
    final report = SyncReport();

    // Deletions first, so a row deleted and re-created with the same id ends up alive.
    for (final d in await db.pendingDeletions()) {
      await remote.markDeleted(d.table, syncSpecFor(d.table).pk, householdId, d.id, d.deletedAt);
      await db.clearDeletion(d);
      report.pushedDeletions++;
    }

    for (final spec in syncTables) {
      final rows = await db.dirtyRows(spec.name);
      for (var i = 0; i < rows.length; i += pushBatch) {
        final chunk = rows.sublist(i, math.min(i + pushBatch, rows.length));
        await remote.upsert(spec.name, spec.pk, householdId, [
          for (final r in chunk)
            {
              for (final e in r.entries)
                if (!localOnlyColumns.contains(e.key)) e.key: e.value,
              'deleted': false,
            }
        ]);
        for (final r in chunk) {
          await db.markClean(spec.name, spec.pk, r[spec.pk] as Object, asInt(r['updated_at']));
        }
        report.pushedRows += chunk.length;
      }
    }

    for (final spec in syncTables) {
      final key = '$householdId:${spec.name}';
      var cursor = await cursors.get(key);
      var after = math.max(0, cursor - lookback);
      while (true) {
        final page = await remote.pull(spec.name, householdId, after, pageSize);
        if (page.isEmpty) break;
        report.pulledChanges += await db.applyRemoteRows(spec.name, spec.pk, page);
        after = asInt(page.last['sync_seq']);
        cursor = math.max(cursor, after);
        if (page.length < pageSize) break;
      }
      await cursors.set(key, cursor);
    }

    return report;
  }
}
