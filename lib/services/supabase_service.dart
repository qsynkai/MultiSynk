import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    final url = AppConfig.supabaseUrl;
    final anonKey = AppConfig.supabaseAnonKey;
    if (url.isEmpty || anonKey.isEmpty) return;
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static bool get isAvailable {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  static User? get currentUser => isAvailable ? client.auth.currentUser : null;
  static bool get isSignedIn => currentUser != null;

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  static Future<AuthResponse> signInWithEmail(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);

  static Future<AuthResponse> signUpWithEmail(String email, String password) =>
      client.auth.signUp(email: email, password: password);

  static Future<void> signOut() => client.auth.signOut();
}
