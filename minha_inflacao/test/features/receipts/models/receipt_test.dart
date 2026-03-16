import 'package:flutter_test/flutter_test.dart';
import 'package:minha_inflacao/features/receipts/data/models/receipt.dart';

void main() {
  group('ReceiptItem.fromJson', () {
    test('parses a complete item', () {
      final json = {
        'ean': '7891000315507',
        'rawName': 'ARROZ TIO JOAO 5KG',
        'quantity': 1,
        'unit': 'un',
        'unitPrice': 25.90,
        'totalPrice': 25.90,
        'confidence': 'high',
      };

      final item = ReceiptItem.fromJson(json);

      expect(item.ean, equals('7891000315507'));
      expect(item.rawName, equals('ARROZ TIO JOAO 5KG'));
      expect(item.confidence, equals(Confidence.high));
    });

    test('handles null EAN', () {
      final json = {
        'ean': null,
        'rawName': 'PRODUTO SEM EAN',
        'quantity': 2,
        'unit': 'kg',
        'unitPrice': 10.0,
        'totalPrice': 20.0,
        'confidence': 'low',
      };

      final item = ReceiptItem.fromJson(json);
      expect(item.ean, isNull);
      expect(item.confidence, equals(Confidence.low));
    });
  });

  group('ParsedReceipt.fromJson', () {
    test('parses parsed receipt with items', () {
      final json = {
        'storeName': 'Supermercado',
        'storeAddress': 'Rua A, 1',
        'cep': '01310',
        'receiptDate': '2024-03-15T00:00:00.000Z',
        'total': 100.0,
        'items': [
          {
            'ean': '123',
            'rawName': 'PROD',
            'quantity': 1,
            'unit': 'un',
            'unitPrice': 100.0,
            'totalPrice': 100.0,
            'confidence': 'high',
          }
        ],
      };

      final parsed = ParsedReceipt.fromJson(json);
      expect(parsed.storeName, equals('Supermercado'));
      expect(parsed.items, hasLength(1));
    });
  });
}
