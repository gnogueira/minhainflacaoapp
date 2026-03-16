import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:minha_inflacao/core/api_client.dart';
import 'package:minha_inflacao/core/exceptions.dart';
import 'package:minha_inflacao/features/receipts/data/models/receipt.dart';
import 'package:minha_inflacao/features/receipts/data/receipt_repository.dart';

ApiClient _makeClient(http.Client httpClient) => ApiClient(
      baseUrl: 'https://api.example.com',
      tokenProvider: () async => 'test-token',
      httpClient: httpClient,
    );

final _parsedReceipt = ParsedReceipt(
  storeName: 'Supermercado',
  storeAddress: 'Rua A',
  cep: '01310',
  receiptDate: '2024-03-15T00:00:00.000Z',
  total: 100.0,
  items: [
    ReceiptItem(
      ean: '123',
      rawName: 'PROD',
      quantity: 1,
      unit: 'un',
      unitPrice: 100.0,
      totalPrice: 100.0,
      confidence: Confidence.high,
    )
  ],
);

void main() {
  group('ReceiptRepository.processReceipt', () {
    test('returns ParsedReceipt and receiptId on success', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'receiptId': 'r-123',
              'status': 'pending_review',
              'parsedData': _parsedReceipt.toJson(),
            }),
            200,
          ));

      final repo = ReceiptRepository(apiClient: _makeClient(mockClient));
      final result = await repo.processReceipt('gs://bucket/img.jpg');

      expect(result.receiptId, equals('r-123'));
      expect(result.parsedData.storeName, equals('Supermercado'));
    });

    test('throws RateLimitException on 429', () async {
      final mockClient = MockClient((_) async =>
          http.Response('{"error":"monthly_limit_reached","limit":50}', 429));

      final repo = ReceiptRepository(apiClient: _makeClient(mockClient));
      expect(
        () => repo.processReceipt('gs://bucket/img.jpg'),
        throwsA(isA<RateLimitException>()),
      );
    });
  });

  group('ReceiptRepository.confirmReceipt', () {
    test('sends confirm request with parsed receipt body', () async {
      http.Request? captured;
      final mockClient = MockClient((request) async {
        captured = request;
        return http.Response('{"receiptId":"r-123","status":"confirmed"}', 200);
      });

      final repo = ReceiptRepository(apiClient: _makeClient(mockClient));
      await repo.confirmReceipt('r-123', _parsedReceipt);

      expect(captured!.url.path, contains('/r-123/confirm'));
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['storeName'], equals('Supermercado'));
    });
  });

  group('ReceiptRepository.getPriceData', () {
    test('returns null when API returns 404', () async {
      final mockClient = MockClient((_) async =>
          http.Response('{"error":"Not enough data"}', 404));

      final repo = ReceiptRepository(apiClient: _makeClient(mockClient));
      final result = await repo.getPriceData('123', '01310');
      expect(result, isNull);
    });

    test('returns PriceData on success', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'ean': '123',
              'cep5': '01310',
              'avgPrice': 25.90,
              'minPrice': 22.0,
              'maxPrice': 28.0,
              'count': 5,
            }),
            200,
          ));

      final repo = ReceiptRepository(apiClient: _makeClient(mockClient));
      final result = await repo.getPriceData('123', '01310');
      expect(result!.avgPrice, equals(25.90));
    });
  });
}
