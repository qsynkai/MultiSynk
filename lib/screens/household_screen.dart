import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/household_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final _codeCtrl = TextEditingController();
  Household? _household;
  List<HouseholdMember> _members = const [];
  bool _loading = true;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final h = await HouseholdService.ensure();
      final members = await HouseholdService.members();
      if (!mounted) return;
      setState(() { _household = h; _members = members; });
    } catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível carregar a casa. Verifique a internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Entrar nesta casa?'),
        content: const Text(
          'Os dados deste aparelho serão juntados aos da casa e vocês passarão a ver e editar as mesmas informações.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Entrar')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() { _joining = true; _error = null; });
    try {
      await HouseholdService.join(_codeCtrl.text);
      _codeCtrl.clear();
      await SyncService.syncAll();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pronto! Agora vocês compartilham os dados.')));
      }
    } on HouseholdException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Não foi possível entrar na casa. Verifique a internet.');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _signOut() async {
    await SupabaseService.signOut();
    await SyncService.onSignedOut();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final h = _household;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.surface, title: const Text('Nossa casa')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await SyncService.syncAll();
                await _load();
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (h != null) ...[
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CÓDIGO DE CONVITE',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(h.inviteCode,
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 4)),
                              ),
                              IconButton(
                                tooltip: 'Copiar código',
                                icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: h.inviteCode));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado')));
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text('Envie este código para quem vai compartilhar os dados com você.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MEMBROS (${_members.length})',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          for (final m in _members)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(children: [
                                const Icon(Icons.person_rounded, color: AppColors.primary, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(m.email, style: const TextStyle(color: AppColors.textPrimary))),
                                if (m.role == 'owner')
                                  const Text('criador', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('ENTRAR NA CASA DE OUTRA PESSOA',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'Código de convite'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _joining ? null : _join,
                          child: _joining
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Entrar com código'),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 16),
                  ValueListenableBuilder<SyncState>(
                    valueListenable: SyncService.state,
                    builder: (_, s, __) => _card(
                      child: Row(children: [
                        Icon(
                          switch (s) {
                            SyncState.syncing => Icons.sync_rounded,
                            SyncState.offline => Icons.cloud_off_rounded,
                            SyncState.error => Icons.error_outline_rounded,
                            SyncState.idle => Icons.cloud_done_rounded,
                          },
                          color: s == SyncState.error ? Colors.redAccent : AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            switch (s) {
                              SyncState.syncing => 'Sincronizando...',
                              SyncState.offline => 'Sem internet: as alterações sobem quando a conexão voltar.',
                              SyncState.error => 'Falha ao sincronizar. Puxe para baixo para tentar de novo.',
                              SyncState.idle => SyncService.lastSyncAt == null
                                  ? 'Sincronização automática ativa.'
                                  : 'Sincronizado às ${DateFormat('HH:mm').format(SyncService.lastSyncAt!)}',
                            },
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        TextButton(onPressed: SyncService.syncAll, child: const Text('Agora')),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Conectado como ${SupabaseService.currentUser?.email ?? ''}',
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  TextButton(onPressed: _signOut, child: const Text('Sair da conta')),
                ],
              ),
            ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
        ),
        child: child,
      );
}
