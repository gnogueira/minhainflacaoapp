import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/receipts_provider.dart';
import '../data/models/receipt.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final receiptsAsync = ref.watch(receiptsProvider);
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.trending_up, color: Colors.blue),
            SizedBox(width: 8),
            Text('Minha Inflação'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/home/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Olá, ${user?.displayName ?? 'usuário'}!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Últimas Compras',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: receiptsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro ao carregar notas: $e')),
                data: (receipts) => receipts.isEmpty
                    ? const Center(child: Text('Nenhuma nota ainda.\nToque em + para adicionar.', textAlign: TextAlign.center))
                    : RefreshIndicator(
                        onRefresh: () => ref.refresh(receiptsProvider.future),
                        child: ListView.separated(
                          itemCount: receipts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => _ReceiptTile(
                            receipt: receipts[i],
                            currencyFormat: currencyFormat,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/receipts/camera'),
        icon: const Icon(Icons.camera_alt),
        label: const Text('Adicionar Nota'),
      ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  final Receipt receipt;
  final NumberFormat currencyFormat;

  const _ReceiptTile({required this.receipt, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.store)),
      title: Text(receipt.storeName),
      subtitle: Text(DateFormat('dd/MM/yyyy').format(receipt.date)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('Total', style: TextStyle(fontSize: 11, color: Colors.grey)),
          Text(
            currencyFormat.format(receipt.total),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      onTap: () => context.push('/receipts/${receipt.id}'),
    );
  }
}

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: GoRouterState.of(context).matchedLocation == '/home/profile' ? 1 : 0,
        onTap: (i) {
          if (i == 0) context.go('/home/receipts');
          if (i == 1) context.go('/home/profile');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Notas'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}
