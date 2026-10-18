import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'supabase_service.dart';
import 'sync_service.dart';

/// Monitora conectividade e dispara sync automático ao reconectar.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  static ConnectivityService get instance => _instance;
  ConnectivityService._();

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _wasOffline = false;

  void start() {
    _sub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  static Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online && _wasOffline) {
      _wasOffline = false;
      if (SupabaseService.isSignedIn) {
        SyncService.syncAll();
      }
    } else if (!online) {
      _wasOffline = true;
    }
  }
}
