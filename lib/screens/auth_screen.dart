import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) return;

    setState(() { _loading = true; _error = null; });
    try {
      if (_isLogin) {
        await SupabaseService.signInWithEmail(email, pass);
      } else {
        await SupabaseService.signUpWithEmail(email, pass);
      }
      if (mounted) {
        SyncService.syncAll();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(_isLogin ? 'Entrar na nuvem' : 'Criar conta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.cloud_sync_rounded, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Sincronize seus dados\nentre dispositivos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha'),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isLogin ? 'Entrar' : 'Criar conta'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() { _isLogin = !_isLogin; _error = null; }),
              child: Text(_isLogin ? 'Não tenho conta' : 'Já tenho conta'),
            ),
          ],
        ),
      ),
    );
  }
}
