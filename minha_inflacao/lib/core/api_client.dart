import 'dart:convert';
import 'package:http/http.dart' as http;
import 'exceptions.dart';

typedef TokenProvider = Future<String?> Function();

class ApiClient {
  final String baseUrl;
  final http.Client _http;
  final TokenProvider _tokenProvider;

  ApiClient({
    required String baseUrl,
    required TokenProvider tokenProvider,
    http.Client? httpClient,
  })  : baseUrl = baseUrl,
        _tokenProvider = tokenProvider,
        _http = httpClient ?? http.Client();

  Future<Map<String, dynamic>> get(String path) async {
    final token = await _tokenProvider();
    final response = await _http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path, {required Map<String, dynamic> body}) async {
    final token = await _tokenProvider();
    final response = await _http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patch(String path, {required Map<String, dynamic> body}) async {
    final token = await _tokenProvider();
    final response = await _http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    switch (response.statusCode) {
      case >= 200 && < 300:
        return body;
      case 401:
        throw const UnauthorizedException();
      case 429:
        throw const RateLimitException();
      default:
        throw ApiException(
          body['error']?.toString() ?? 'Unknown error',
          statusCode: response.statusCode,
        );
    }
  }
}
