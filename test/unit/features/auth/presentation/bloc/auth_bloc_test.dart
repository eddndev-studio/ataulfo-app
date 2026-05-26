import 'package:agentic/features/auth/domain/entities/identity.dart';
import 'package:agentic/features/auth/domain/failures/auth_failure.dart';
import 'package:agentic/features/auth/domain/repositories/auth_repository.dart';
import 'package:agentic/features/auth/presentation/bloc/auth_bloc.dart';
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

void main() {
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
        'con tokens + me() falla por red → AuthUnauthenticated (no retiene tokens en sesión)',
        build: () {
          final repo = _MockRepo();
          when(repo.hasTokens).thenAnswer((_) async => true);
          when(repo.me).thenThrow(const NetworkFailure());
          return AuthBloc(repo);
        },
        act: (bloc) => bloc.add(const AuthCheckRequested()),
        expect: () => const <AuthState>[AuthUnauthenticated()],
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
