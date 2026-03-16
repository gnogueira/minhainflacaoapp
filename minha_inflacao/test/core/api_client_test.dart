import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:minha_inflacao/core/api_client.dart';
import 'package:minha_inflacao/core/exceptions.dart';

void main() {
  group('ApiClient', () {
    test('attaches Bearer token to every request', () async {
      http.Request? captured;
      final mockClient = MockClient((request) async {
        captured = request;
        return http.Response('{"status":"ok"}', 200);
      });

      final apiClient = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: mockClient,
        tokenProvider: () async => 'test-token-123',
      );

      await apiClient.get('/health');

      expect(captured!.headers['Authorization'], equals('Bearer test-token-123'));
    });

    test('throws RateLimitException on 429 response', () async {
      final mockClient = MockClient((_) async =>
          http.Response('{"error":"monthly_limit_reached","limit":50}', 429));

      final apiClient = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: mockClient,
        tokenProvider: () async => 'token',
      );

      expect(() => apiClient.post('/receipts', body: {}), throwsA(isA<RateLimitException>()));
    });

    test('throws UnauthorizedException on 401 response', () async {
      final mockClient = MockClient((_) async =>
          http.Response('{"error":"Invalid token"}', 401));

      final apiClient = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: mockClient,
        tokenProvider: () async => 'token',
      );

      expect(() => apiClient.get('/receipts'), throwsA(isA<UnauthorizedException>()));
    });

    test('throws ApiException with status code on non-2xx response', () async {
      final mockClient = MockClient((_) async =>
          http.Response('{"error":"Not found"}', 404));

      final apiClient = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: mockClient,
        tokenProvider: () async => 'token',
      );

      expect(
        () => apiClient.get('/receipts/bad-id'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('returns decoded JSON body on 2xx response', () async {
      final mockClient = MockClient((_) async =>
          http.Response(jsonEncode({'receiptId': 'r-123'}), 200));

      final apiClient = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: mockClient,
        tokenProvider: () async => 'token',
      );

      final result = await apiClient.post('/receipts', body: {'storageImagePath': 'gs://x'});
      expect(result['receiptId'], equals('r-123'));
    });
  });
}
