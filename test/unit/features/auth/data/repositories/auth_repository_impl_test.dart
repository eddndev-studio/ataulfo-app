import 'package:agentic/features/auth/data/datasources/auth_datasource.dart';
import 'package:agentic/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:agentic/features/auth/data/repositories/token_storage.dart';
import 'package:agentic/features/auth/domain/entities/auth_tokens.dart';
import 'package:agentic/features/auth/domain/entities/identity.dart';
import 'package:agentic/features/auth/domain/failures/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements AuthDatasource {}

class _SpyStorage implements TokenStorage {
  final List<AuthTokens> saved = <AuthTokens>[];
  int clears = 0;

  @override
  Future<void> save(AuthTokens tokens) async => saved.add(tokens);

  @override
  Future<AuthTokens?> read() async => saved.isEmpty ? null : saved.last;

  @override
  Future<void> clear() async => clears++;
}

void main() {
  late _MockDs ds;
  late _SpyStorage storage;
  late AuthRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    storage = _SpyStorage();
    repo = AuthRepositoryImpl(datasource: ds, storage: storage);
  });

  group('login', () {
    test('OK guarda los tokens y los devuelve', () async {
      const tokens = AuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        tokenType: 'Bearer',
        expiresInSeconds: 900,
      );
      when(
        () => ds.login(email: 'op@x.com', password: 'p'),
      ).thenAnswer((_) async => tokens);

      final got = await repo.login(email: 'op@x.com', password: 'p');

      expect(got, tokens);
      expect(storage.saved, <AuthTokens>[tokens]);
    });

    test('falla del datasource propaga y no persiste tokens', () async {
      when(
        () => ds.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const InvalidCredentialsFailure());

      await expectLater(
        repo.login(email: 'x@y.z', password: 'bad'),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
      expect(storage.saved, isEmpty);
    });
  });

  group('me', () {
    test('OK devuelve la identidad del datasource sin tocar storage', () async {
      const identity = Identity(userId: 'u1', orgId: 'o1', role: 'OWNER');
      when(() => ds.me()).thenAnswer((_) async => identity);

      final got = await repo.me();

      expect(got, identity);
      expect(storage.saved, isEmpty);
      expect(storage.clears, 0);
    });

    test('falla del datasource propaga sin tocar storage', () async {
      when(() => ds.me()).thenThrow(const InvalidCredentialsFailure());

      await expectLater(repo.me(), throwsA(isA<InvalidCredentialsFailure>()));
      expect(storage.saved, isEmpty);
      expect(storage.clears, 0);
    });
  });

  group('logout', () {
    test('sin tokens persistidos: no llama al datasource y no falla', () async {
      // Storage empieza vacío (saved.isEmpty → read() = null).
      await repo.logout();

      verifyNever(() => ds.logout(any()));
      expect(storage.clears, 0);
    });
  });
}
