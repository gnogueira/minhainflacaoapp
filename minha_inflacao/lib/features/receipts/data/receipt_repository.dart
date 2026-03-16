import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/api_client.dart';
import '../../../core/exceptions.dart';
import 'models/receipt.dart';
import 'models/price_data.dart';

class ProcessReceiptResult {
  final String receiptId;
  final ParsedReceipt parsedData;
  const ProcessReceiptResult({required this.receiptId, required this.parsedData});
}

class ReceiptRepository {
  final ApiClient _api;
  final FirebaseStorage? _storageOverride;

  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  ReceiptRepository({
    required ApiClient apiClient,
    FirebaseStorage? storage,
  })  : _api = apiClient,
        _storageOverride = storage;

  /// Uploads image to Firebase Storage, then calls POST /receipts.
  /// If [localImagePath] already starts with 'gs://', it is used directly
  /// as the GCS path (useful in tests to bypass file upload).
  Future<ProcessReceiptResult> processReceipt(String localImagePath) async {
    String gcsPath;
    if (localImagePath.startsWith('gs://')) {
      // Already a GCS path (used in tests)
      gcsPath = localImagePath;
    } else {
      final storageRef =
          _storage.ref('receipts/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putData(await readFileBytes(localImagePath));
      gcsPath = 'gs://${storageRef.bucket}/${storageRef.fullPath}';
    }

    final response =
        await _api.post('/receipts', body: {'storageImagePath': gcsPath});

    return ProcessReceiptResult(
      receiptId: response['receiptId'] as String,
      parsedData:
          ParsedReceipt.fromJson(response['parsedData'] as Map<String, dynamic>),
    );
  }

  /// Override in subclasses to provide platform-specific file reading.
  Future<Uint8List> readFileBytes(String path) async {
    throw UnimplementedError('Subclasses must override readFileBytes');
  }

  Future<void> confirmReceipt(String receiptId, ParsedReceipt data) async {
    await _api.patch('/receipts/$receiptId/confirm', body: data.toJson());
  }

  Future<List<Receipt>> listReceipts({int limit = 20, String? cursor}) async {
    final query =
        cursor != null ? '?limit=$limit&cursor=$cursor' : '?limit=$limit';
    final response = await _api.get('/receipts$query');
    return (response['items'] as List)
        .map((e) => Receipt.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getReceiptDetail(String receiptId) async {
    return _api.get('/receipts/$receiptId');
  }

  /// Returns null if no regional data (404 or count < 3).
  Future<PriceData?> getPriceData(String ean, String cep5) async {
    try {
      final response = await _api.get('/prices/$ean?region=$cep5');
      return PriceData.fromJson(response);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}
