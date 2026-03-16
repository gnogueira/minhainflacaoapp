import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../data/models/price_data.dart';
import '../data/models/receipt.dart';
import '../providers/receipts_provider.dart';

class ReceiptDetailScreen extends ConsumerWidget {
  final String receiptId;
  const ReceiptDetailScreen({super.key, required this.receiptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(receiptDetailProvider(receiptId));
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes da Nota')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (detail) {
          final receipt = Receipt.fromJson(detail['receipt'] as Map<String, dynamic>);
          final items = (detail['items'] as List)
              .map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
              .toList();

          return ListView(
            children: [
              _ReceiptHeader(receipt: receipt, currencyFormat: currencyFormat),
              const Divider(),
              ...items.map((item) => _ItemRow(
                    item: item,
                    cep5: receipt.cep5,
                    currencyFormat: currencyFormat,
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _ReceiptHeader extends StatelessWidget {
  final Receipt receipt;
  final NumberFormat currencyFormat;

  const _ReceiptHeader({required this.receipt, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(receipt.storeName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(receipt.storeAddress, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('dd/MM/yyyy').format(receipt.date)),
              Text(
                'Total: ${currencyFormat.format(receipt.total)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  final ReceiptItem item;
  final String cep5;
  final NumberFormat currencyFormat;

  const _ItemRow({required this.item, required this.cep5, required this.currencyFormat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(item.rawName)),
              Text(
                currencyFormat.format(item.unitPrice),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (item.ean != null) _PriceComparison(ean: item.ean!, cep5: cep5, paidPrice: item.unitPrice, currencyFormat: currencyFormat),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

class _PriceComparison extends ConsumerWidget {
  final String ean;
  final String cep5;
  final double paidPrice;
  final NumberFormat currencyFormat;

  const _PriceComparison({
    required this.ean,
    required this.cep5,
    required this.paidPrice,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceAsync = ref.watch(_priceDataProvider((ean: ean, cep5: cep5)));

    return priceAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 4),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (priceData) {
        if (priceData == null) return const SizedBox.shrink();

        final diff = paidPrice - priceData.avgPrice;
        final isAboveAvg = diff > 0;
        final color = isAboveAvg ? AppTheme.error : AppTheme.success;
        final label = isAboveAvg ? 'Acima da média' : 'Abaixo da média';

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(Icons.trending_up, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                'Média na região: ${currencyFormat.format(priceData.avgPrice)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Private provider scoped to (ean, cep5) tuple
final _priceDataProvider = FutureProvider.family<PriceData?, ({String ean, String cep5})>(
  (ref, args) => ref.watch(receiptRepositoryProvider).getPriceData(args.ean, args.cep5),
);
