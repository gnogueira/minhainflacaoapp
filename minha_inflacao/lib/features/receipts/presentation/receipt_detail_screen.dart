import 'package:flutter/material.dart';
class ReceiptDetailScreen extends StatelessWidget {
  final String receiptId;
  const ReceiptDetailScreen({super.key, required this.receiptId});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Detail')));
}
