import 'package:flutter/material.dart';
import '../data/models/receipt.dart';
class ReviewScreen extends StatelessWidget {
  final ParsedReceipt parsedReceipt;
  final String receiptId;
  const ReviewScreen({super.key, required this.parsedReceipt, required this.receiptId});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Review')));
}
