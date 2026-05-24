import 'package:agentic/features/auth/domain/entities/identity.dart';
import 'package:agentic/features/auth/domain/repositories/auth_repository.dart';
import 'package:agentic/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

const _identity = Identity(userId: 'u1', orgId: 'o1', role: 'OWNER');

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
    });
  });
}
