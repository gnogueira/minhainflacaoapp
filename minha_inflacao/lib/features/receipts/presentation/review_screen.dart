import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/exceptions.dart';
import '../data/models/receipt.dart';
import '../providers/receipts_provider.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final ParsedReceipt parsedReceipt;
  final String receiptId;

  const ReviewScreen({
    super.key,
    required this.parsedReceipt,
    required this.receiptId,
  });

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late TextEditingController _storeNameCtrl;
  late TextEditingController _storeAddressCtrl;
  late TextEditingController _cepCtrl;
  late List<ReceiptItem> _items;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.parsedReceipt;
    _storeNameCtrl = TextEditingController(text: p.storeName);
    _storeAddressCtrl = TextEditingController(text: p.storeAddress);
    _cepCtrl = TextEditingController(text: p.cep);
    _items = List.from(p.items);
  }

  Future<void> _confirm() async {
    setState(() { _loading = true; _error = null; });
    try {
      final confirmed = widget.parsedReceipt.copyWith(
        storeName: _storeNameCtrl.text.trim(),
        storeAddress: _storeAddressCtrl.text.trim(),
        cep: _cepCtrl.text.replaceAll(RegExp(r'\D'), ''),
        items: _items,
      );
      await ref.read(receiptRepositoryProvider).confirmReceipt(widget.receiptId, confirmed);
      ref.invalidate(receiptsProvider);
      if (mounted) context.go('/home/receipts');
    } on RateLimitException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erro ao confirmar nota. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar Nota'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _confirm,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Confirmar'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const Text('Estabelecimento', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _storeNameCtrl,
              decoration: const InputDecoration(labelText: 'Nome do estabelecimento', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _storeAddressCtrl,
              decoration: const InputDecoration(labelText: 'Endereço', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cepCtrl,
              decoration: const InputDecoration(labelText: 'CEP', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Itens', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar item'),
                ),
              ],
            ),
            ..._items.asMap().entries.map((entry) => _ItemTile(
                  index: entry.key,
                  item: entry.value,
                  currencyFormat: currencyFormat,
                  onChanged: (updated) => setState(() => _items[entry.key] = updated),
                  onRemove: () => setState(() => _items.removeAt(entry.key)),
                )),
          ],
        ),
      ),
    );
  }

  void _addItem() {
    setState(() {
      _items.add(ReceiptItem(
        ean: null,
        rawName: '',
        quantity: 1,
        unit: 'un',
        unitPrice: 0,
        totalPrice: 0,
        confidence: Confidence.high,
      ));
    });
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _storeAddressCtrl.dispose();
    _cepCtrl.dispose();
    super.dispose();
  }
}

class _ItemTile extends StatelessWidget {
  final int index;
  final ReceiptItem item;
  final NumberFormat currencyFormat;
  final ValueChanged<ReceiptItem> onChanged;
  final VoidCallback onRemove;

  const _ItemTile({
    required this.index,
    required this.item,
    required this.currencyFormat,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isLowConfidence = item.confidence == Confidence.low;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isLowConfidence ? Colors.amber.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isLowConfidence)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                  ),
                Expanded(
                  child: TextFormField(
                    initialValue: item.rawName,
                    decoration: const InputDecoration(labelText: 'Nome', isDense: true, border: OutlineInputBorder()),
                    onChanged: (v) => onChanged(item.copyWith(rawName: v)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.ean ?? '',
                    decoration: const InputDecoration(
                      labelText: 'EAN',
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: 'opcional',
                    ),
                    onChanged: (v) => onChanged(item.copyWith(ean: v.isEmpty ? null : v)),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: item.unitPrice.toStringAsFixed(2),
                    decoration: const InputDecoration(labelText: 'Preço un.', isDense: true, border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final price = double.tryParse(v.replaceAll(',', '.')) ?? item.unitPrice;
                      onChanged(item.copyWith(unitPrice: price, totalPrice: price * item.quantity));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
