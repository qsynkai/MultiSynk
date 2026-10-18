import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../sync/supabase_remote_store.dart';
import '../sync/sync_engine.dart';
import 'connectivity_service.dart';
import 'household_service.dart';
import 'supabase_service.dart';

enum SyncState { idle, syncing, offline, error }

/// Two-way sync between the local SQLite database (source of truth on the device, works offline)
/// and the household's data in the cloud. Safe to call often: concurrent calls coalesce.
class SyncService {
  static const _pendingKey = 'sync_pending';
  static const _householdKey = 'sync_household_id';
  static const _debounce = Duration(seconds: 3);

  /// Bumped whenever data pulled from the cloud changed the local database.
  static final dataVersion = ValueNotifier<int>(0);
  static final state = ValueNotifier<SyncState>(SyncState.idle);
  static String? lastError;
  static DateTime? lastSyncAt;

  static bool _running = false;
  static bool _rerun = false;
  static Timer? _timer;

  /// Debounced sync after a local edit.
  static void scheduleSync() {
    if (!SupabaseService.isSignedIn) return;
    _timer?.cancel();
    _timer = Timer(_debounce, syncAll);
  }

  static Future<void> syncAll() async {
    if (!SupabaseService.isSignedIn) return;
    if (_running) {
      _rerun = true;
      return;
    }
    _running = true;
    try {
      do {
        _rerun = false;
        await _runOnce();
      } while (_rerun);
    } finally {
      _running = false;
    }
  }

  static Future<void> _runOnce() async {
    if (!await ConnectivityService.isOnline()) {
      await _setPending(true);
      state.value = SyncState.offline;
      return;
    }
    state.value = SyncState.syncing;
    try {
      final household = await HouseholdService.ensure();
      final prefs = await SharedPreferences.getInstance();
      final cursors = PrefsCursorStore();
      if (prefs.getString(_householdKey) != household.id) {
        // New account or new household: everything on this device must go up to it.
        await DatabaseHelper.instance.markAllDirty();
        await cursors.clear();
        await prefs.setString(_householdKey, household.id);
      }
      final report = await SyncEngine(
        DatabaseHelper.instance,
        SupabaseRemoteStore(SupabaseService.client),
        cursors,
      ).run(household.id);
      await _setPending(false);
      lastError = null;
      lastSyncAt = DateTime.now();
      state.value = SyncState.idle;
      if (report.pulledChanges > 0) dataVersion.value++;
    } catch (e) {
      lastError = e.toString();
      await _setPending(true);
      state.value = SyncState.error;
    }
  }

  static Future<bool> hasPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingKey) ?? false;
  }

  static Future<void> _setPending(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, value);
  }

  /// After sign-out the next account must re-upload this device's data to its own household.
  static Future<void> onSignedOut() async {
    _timer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_householdKey);
    await PrefsCursorStore().clear();
    state.value = SyncState.idle;
  }
}
