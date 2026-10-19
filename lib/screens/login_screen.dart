import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../app.dart';

class _UserEntry {
  final String pin;
  final String email;
  final String supaPass;
  const _UserEntry(this.pin, this.email, this.supaPass);
}

const _users = <String, _UserEntry>{
  'igor': _UserEntry('0000', 'igor@multisynk.app', 'Multi2026!'),
  'regina': _UserEntry('0000', 'esposa@multisynk.app', 'Multi2026!'),
};

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static Future<String?> loggedUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('logged_user');
  }

  static Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_user');
    try {
      await SyncService.onSignedOut();
      await SupabaseService.signOut();
    } catch (_) {}
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final user = _userCtrl.text.trim().toLowerCase();
    final pin = _pinCtrl.text.trim();
    if (user.isEmpty || pin.isEmpty) {
      setState(() => _error = 'Preencha usuário e senha.');
      return;
    }
    final entry = _users[user];
    if (entry == null || entry.pin != pin) {
      setState(() => _error = 'Usuário ou senha incorretos.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logged_user', user);

    if (SupabaseService.isAvailable) {
      try {
        await SupabaseService.signInWithEmail(entry.email, entry.supaPass);
        SyncService.syncAll();
      } catch (e) {
        debugPrint('[Login] Supabase sign-in failed: $e');
      }
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MultiSynkApp()),
        (_) => false,
      );
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 64, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                'MultiSynk',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Entre com seu usuário',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _userCtrl,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  labelText: 'Usuário',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: Icon(Icons.pin_rounded),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Entrar', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
