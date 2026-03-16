import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final authRepo = ref.read(authRepositoryProvider);
    final profileRepo = ref.read(profileRepositoryProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(user?.displayName ?? ''),
              subtitle: Text(user?.email ?? ''),
            ),
            const Divider(),
            _CepTile(
              cep5: profile?.cep5 ?? '',
              onSave: (cep5) async {
                if (user != null) await profileRepo.updateCep5(user.uid, cep5);
              },
            ),
            SwitchListTile(
              title: const Text('Compartilhar preços anonimamente'),
              subtitle: const Text(
                'Seus preços contribuem para a média regional.',
                style: TextStyle(fontSize: 12),
              ),
              value: profile?.consentSharing ?? false,
              onChanged: user == null
                  ? null
                  : (v) => profileRepo.updateConsentSharing(user.uid, v),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.orange),
              title: const Text('Sair'),
              onTap: () async {
                await authRepo.signOut();
                if (context.mounted) context.go('/auth/login');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Excluir conta', style: TextStyle(color: Colors.red)),
              onTap: () => _confirmDeleteAccount(context, authRepo),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, dynamic authRepo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: const Text('Todos os seus dados serão removidos permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authRepo.deleteAccount();
              if (context.mounted) context.go('/onboarding');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

class _CepTile extends StatefulWidget {
  final String cep5;
  final Future<void> Function(String) onSave;

  const _CepTile({required this.cep5, required this.onSave});

  @override
  State<_CepTile> createState() => _CepTileState();
}

class _CepTileState extends State<_CepTile> {
  late final TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.cep5);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.location_on_outlined),
      title: _editing
          ? TextFormField(
              controller: _ctrl,
              decoration: const InputDecoration(labelText: 'CEP (5 dígitos)', isDense: true),
              keyboardType: TextInputType.number,
              maxLength: 8,
            )
          : Text(_ctrl.text.isEmpty ? 'CEP não definido' : 'CEP: ${_ctrl.text}'),
      trailing: _editing
          ? TextButton(
              onPressed: () async {
                final digits = _ctrl.text.replaceAll(RegExp(r'\D'), '');
                if (digits.length < 5) return; // guard: need at least 5 digits
                await widget.onSave(digits.substring(0, 5));
                setState(() => _editing = false);
              },
              child: const Text('Salvar'),
            )
          : IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
            ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
