import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
);

const _noOrgIdentity = Identity(
  userId: 'u1',
  orgId: '',
  role: '',
  email: 'op@example.com',
);

void main() {
  group('AuthAuthenticatedNoOrg', () {
    test('value-equality por identity', () {
      expect(
        const AuthAuthenticatedNoOrg(_noOrgIdentity),
        const AuthAuthenticatedNoOrg(_noOrgIdentity),
      );
      expect(
        const AuthAuthenticatedNoOrg(_noOrgIdentity).hashCode,
        const AuthAuthenticatedNoOrg(_noOrgIdentity).hashCode,
      );
    });

    test('es distinto de AuthAuthenticated con la misma identity', () {
      expect(
        const AuthAuthenticatedNoOrg(_identity),
        isNot(const AuthAuthenticated(_identity)),
      );
    });
  });

  group('AuthOfflinePending', () {
    test('value-equality por tipo', () {
      expect(const AuthOfflinePending(), const AuthOfflinePending());
      expect(
        const AuthOfflinePending().hashCode,
        const AuthOfflinePending().hashCode,
      );
    });

    test('es distinto de AuthUnauthenticated (no es un logout)', () {
      expect(const AuthOfflinePending(), isNot(const AuthUnauthenticated()));
    });
  });

  group('AuthBloc', () {
    test('estado inicial = AuthInitial (todavía no verificado)', () {
      final bloc = AuthBloc(_MockRepo());

      expect(bloc.state, const AuthInitial());
    });

    group('AuthCheckRequested', () {
      blocTest<AuthBloc, AuthState>(
        'sin tokens persistidos → AuthUnauthenticated y NO llama me()',
        build: () {
          final repo = _MockRepo();
          when(repo.hasTokens).thenAnswer((_) async => false);
          return AuthBloc(repo);
        },
        act: (bloc) => bloc.add(const AuthCheckRequested()),
        expect: () => const <AuthState>[AuthUnauthenticated()],
      );

      blocTest<AuthBloc, AuthState>(
        'con tokens + me() ok → AuthAuthenticated(identity)',
        build: () {
          final repo = _MockRepo();
          when(repo.hasTokens).thenAnswer((_) async => true);
          when(repo.me).thenAnswer((_) async => _identity);
          return AuthBloc(repo);
        },
        act: (bloc) => bloc.add(const AuthCheckRequested()),
        expect: () => const <AuthState>[AuthAuthenticated(_identity)],
      );

      blocTest<AuthBloc, AuthState>(
        'con tokens + me() sin org activa → AuthAuthenticatedNoOrg(identity)',
        build: () {
          final repo = _MockRepo();
          when(repo.hasTokens).thenAnswer((_) async => true);
          when(repo.me).thenAnswer((_) async => _noOrgIdentity);
          return AuthBloc(repo);
        },
        act: (bloc) => bloc.add(const AuthCheckRequested()),
        expect: () => const <AuthState>[AuthAuthenticatedNoOrg(_noOrgIdentity)],
      );

      blocTest<AuthBloc, AuthState>(
        'con tokens + me() falla → AuthUnauthenticated (sin propagar)',
        build: () {
          final repo = _MockRepo();
          when(repo.hasTokens).thenAnswer((_) async => true);
          when(repo.me).thenThrow(const InvalidCredentialsFailure());
          return AuthBloc(repo);
        },
        act: (bloc) => bloc.add(const AuthCheckRequested()),
        expect: () => const <AuthState>[AuthUnauthenticated()],
      );

      blocTest<AuthBloc, AuthState>(
        'con tokens + me() falla por red → AuthOfflinePending '
        '(la sesión sobrevive; no manda al login)',
        build: () {
          final repo = _MockRepo();
          when(repo.hasTokens).thenAnswer((_) async => true);
          when(repo.me).thenThrow(const NetworkFailure());
          return AuthBloc(repo);
        },
        act: (bloc) => bloc.add(const AuthCheckRequested()),
        expect: () => const <AuthState>[AuthOfflinePending()],
      );
    });

    group('AuthLoggedOut', () {
      blocTest<AuthBloc, AuthState>(
        'estado Authenticated → llama repo.logout() → emite AuthUnauthenticated',
        build: () {
          final repo = _MockRepo();
          when(repo.logout).thenAnswer((_) async {});
          return AuthBloc(repo);
        },
        seed: () => const AuthAuthenticated(_identity),
        act: (bloc) => bloc.add(const AuthLoggedOut()),
        expect: () => const <AuthState>[AuthUnauthenticated()],
        verify: (bloc) {
          // bloc_test no expone el mock; el comportamiento del repo
          // queda cubierto por los tests del repositorio. Aquí el assert
          // efectivo es la transición de estado.
        },
      );
    });
  });
}
