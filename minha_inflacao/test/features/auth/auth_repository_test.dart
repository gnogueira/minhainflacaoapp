import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:minha_inflacao/features/auth/data/auth_repository.dart';

@GenerateMocks([FirebaseAuth, UserCredential, User])
import 'auth_repository_test.mocks.dart';

void main() {
  late AuthRepository repo;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    repo = AuthRepository(auth: mockAuth);
  });

  group('signInWithEmail', () {
    test('calls signInWithEmailAndPassword with correct args', () async {
      final mockCred = MockUserCredential();
      when(mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).thenAnswer((_) async => mockCred);

      await repo.signInWithEmail('test@example.com', 'password123');

      verify(mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).called(1);
    });
  });

  group('registerWithEmail', () {
    test('creates user and updates displayName', () async {
      final mockCred = MockUserCredential();
      final mockUser = MockUser();
      when(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCred);
      when(mockCred.user).thenReturn(mockUser);
      when(mockUser.updateDisplayName(any)).thenAnswer((_) async {});

      await repo.registerWithEmail('Test User', 'test@example.com', 'password123');

      verify(mockUser.updateDisplayName('Test User')).called(1);
    });
  });

  group('signOut', () {
    test('calls FirebaseAuth.signOut', () async {
      when(mockAuth.signOut()).thenAnswer((_) async {});

      await repo.signOut();

      verify(mockAuth.signOut()).called(1);
    });
  });
}
