import 'package:agentic/features/auth/domain/entities/auth_tokens.dart';
import 'package:agentic/features/auth/domain/failures/auth_failure.dart';
import 'package:agentic/features/auth/domain/repositories/auth_repository.dart';
import 'package:agentic/features/auth/presentation/bloc/login_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  const tokens = AuthTokens(
    accessToken: 'a',
    refreshToken: 'r',
    tokenType: 'Bearer',
    expiresInSeconds: 900,
  );

  group('LoginBloc', () {
    test('estado inicial es LoginInitial', () {
      expect(LoginBloc(repo).state, const LoginInitial());
    });

    blocTest<LoginBloc, LoginState>(
      'OK: Submitting → Succeeded',
      build: () {
        when(
          () => repo.login(email: 'op@x.com', password: 'hunter2-secret'),
        ).thenAnswer((_) async => tokens);
        return LoginBloc(repo);
      },
      act: (b) => b.add(
        const LoginSubmitted(email: 'op@x.com', password: 'hunter2-secret'),
      ),
      expect: () => const <LoginState>[
        LoginSubmitting(),
        LoginSucceeded(tokens),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      '401: Submitting → Failed(invalidCredentials)',
      build: () {
        when(
          () => repo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const InvalidCredentialsFailure());
        return LoginBloc(repo);
      },
      act: (b) => b.add(const LoginSubmitted(email: 'x@y.z', password: 'bad')),
      expect: () => const <LoginState>[
        LoginSubmitting(),
        LoginFailed(LoginFailureKind.invalidCredentials),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      '429: Submitting → Failed(rateLimited)',
      build: () {
        when(
          () => repo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const RateLimitedFailure());
        return LoginBloc(repo);
      },
      act: (b) => b.add(const LoginSubmitted(email: 'x@y.z', password: 'p')),
      expect: () => const <LoginState>[
        LoginSubmitting(),
        LoginFailed(LoginFailureKind.rateLimited),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'timeout: Submitting → Failed(network)',
      build: () {
        when(
          () => repo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const NetworkFailure());
        return LoginBloc(repo);
      },
      act: (b) => b.add(const LoginSubmitted(email: 'x@y.z', password: 'p')),
      expect: () => const <LoginState>[
        LoginSubmitting(),
        LoginFailed(LoginFailureKind.network),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      '5xx u otro: Submitting → Failed(unknown)',
      build: () {
        when(
          () => repo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const UnknownAuthFailure());
        return LoginBloc(repo);
      },
      act: (b) => b.add(const LoginSubmitted(email: 'x@y.z', password: 'p')),
      expect: () => const <LoginState>[
        LoginSubmitting(),
        LoginFailed(LoginFailureKind.unknown),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'email vacío: no llama al repo, emite Failed(invalidInput)',
      build: () => LoginBloc(repo),
      act: (b) => b.add(const LoginSubmitted(email: '', password: 'p')),
      expect: () => const <LoginState>[
        LoginFailed(LoginFailureKind.invalidInput),
      ],
      verify: (_) {
        verifyNever(
          () => repo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      },
    );
  });
}
