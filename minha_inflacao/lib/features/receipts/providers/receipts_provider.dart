import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../data/models/receipt.dart';
import '../data/receipt_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return ApiClient(
    baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://YOUR_CLOUD_RUN_URL'),
    tokenProvider: () => authRepo.getIdToken(),
  );
});

final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  return ReceiptRepository(apiClient: ref.watch(apiClientProvider));
});

final receiptsProvider = FutureProvider<List<Receipt>>((ref) {
  return ref.watch(receiptRepositoryProvider).listReceipts();
});

final receiptDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, receiptId) {
  return ref.watch(receiptRepositoryProvider).getReceiptDetail(receiptId);
});
