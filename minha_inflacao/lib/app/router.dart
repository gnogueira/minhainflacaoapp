import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/receipts/presentation/home_screen.dart';
import '../features/receipts/presentation/camera_screen.dart';
import '../features/receipts/presentation/review_screen.dart';
import '../features/receipts/presentation/receipt_detail_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/receipts/data/models/receipt.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home/receipts',
    redirect: (context, state) async {
      final isLoggedIn = authState.valueOrNull != null;
      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('onboarding_done') ?? false;

      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (!isLoggedIn && !isAuthRoute && !isOnboarding) {
        return onboardingDone ? '/auth/login' : '/onboarding';
      }
      if (isLoggedIn && (isAuthRoute || isOnboarding)) {
        return '/home/receipts';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: '/home/receipts', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/home/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/receipts/camera', builder: (_, __) => const CameraScreen()),
      GoRoute(
        path: '/receipts/review',
        builder: (_, state) {
          final parsedReceipt = state.extra as ParsedReceipt;
          return ReviewScreen(parsedReceipt: parsedReceipt, receiptId: state.uri.queryParameters['receiptId']!);
        },
      ),
      GoRoute(
        path: '/receipts/:id',
        builder: (_, state) => ReceiptDetailScreen(receiptId: state.pathParameters['id']!),
      ),
    ],
  );
});
