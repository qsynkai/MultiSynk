import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'household_screen.dart';

String authErrorMessage(AuthException e) {
  final m = e.message.toLowerCase();
  final code = (e.code ?? '').toLowerCase();
  if (code == 'invalid_credentials' || m.contains('invalid login')) return 'E-mail ou senha incorretos.';
  if (code == 'email_not_confirmed' || m.contains('not confirmed')) {
    return 'Confirme seu e-mail pelo link que enviamos antes de entrar.';
  }
  if (code == 'user_already_exists' || m.contains('already registered')) {
    return 'Este e-mail já tem conta. Toque em "Já tenho conta" e entre.';
  }
  if (code == 'weak_password' || m.contains('password should')) return 'Senha fraca: use pelo menos 6 caracteres.';
  if (code == 'over_email_send_rate_limit' || m.contains('rate limit')) {
    return 'Muitas tentativas de envio de e-mail. Aguarde alguns minutos e tente de novo.';
  }
  if (m.contains('error sending') || m.contains('confirmation email')) {
    return 'A nuvem não conseguiu enviar o e-mail de confirmação. A conta pode ser criada pelo painel do Supabase.';
  }
  if (code == 'email_address_invalid' || (m.contains('invalid') && m.contains('email'))) return 'E-mail inválido.';
  return 'Não foi possível entrar: ${e.message}';
}

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

  String? _info;

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Preencha e-mail e senha.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'E-mail inválido.');
      return;
    }
    if (!_isLogin && pass.length < 6) {
      setState(() => _error = 'A senha precisa ter pelo menos 6 caracteres.');
      return;
    }
    if (!SupabaseService.isAvailable) {
      setState(() => _error = 'Nuvem não configurada neste aparelho.');
      return;
    }

    setState(() { _loading = true; _error = null; _info = null; });
    try {
      final res = _isLogin
          ? await SupabaseService.signInWithEmail(email, pass)
          : await SupabaseService.signUpWithEmail(email, pass);
      if (res.session == null) {
        // Sign-up succeeded but the project requires e-mail confirmation first.
        setState(() {
          _isLogin = true;
          _info = 'Conta criada! Abra o e-mail que enviamos para $email, confirme, e depois entre aqui.';
        });
        return;
      }
      SyncService.syncAll();
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HouseholdScreen()));
      }
    } on AuthException catch (e) {
      setState(() => _error = authErrorMessage(e));
    } catch (_) {
      setState(() => _error = 'Sem conexão com a nuvem. Verifique a internet e tente de novo.');
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
            if (_info != null) ...[
              const SizedBox(height: 12),
              Text(_info!, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
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
              onPressed: () => setState(() { _isLogin = !_isLogin; _error = null; _info = null; }),
              child: Text(_isLogin ? 'Não tenho conta' : 'Já tenho conta'),
            ),
          ],
        ),
      ),
    );
  }
}
