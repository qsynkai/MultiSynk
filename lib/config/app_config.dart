import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centraliza acesso a variáveis de ambiente.
/// - Mobile/desktop: lê de .env via flutter_dotenv
/// - Web: lê de --dart-define (baked no build)
class AppConfig {
  // Valores injetados via --dart-define no build web
  static const _supabaseUrlDef = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseKeyDef = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get supabaseUrl =>
      kIsWeb ? _supabaseUrlDef : (dotenv.env['SUPABASE_URL'] ?? '');

  static String get supabaseAnonKey =>
      kIsWeb ? _supabaseKeyDef : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');

  // Never embed the OpenAI key in the web bundle: compiled JS is publicly readable.
  static String get openaiApiKey =>
      kIsWeb ? '' : (dotenv.env['OPENAI_API_KEY'] ?? '');
}
