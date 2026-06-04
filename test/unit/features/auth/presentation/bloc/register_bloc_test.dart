import 'package:ataulfo/features/auth/domain/entities/auth_tokens.dart';
import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/register_bloc.dart';
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

  // Contraseña de 12+ chars que satisface el mínimo del backend; las pruebas
  // de éxito la reutilizan tal cual en email/password/confirm.
  const validPassword = 'hunter2-secret';

  group('RegisterBloc', () {
    test('estado inicial es RegisterInitial', () {
      expect(RegisterBloc(repo).state, const RegisterInitial());
    });

    blocTest<RegisterBloc, RegisterState>(
      'OK: Submitting → Succeeded y llama a register una vez',
      build: () {
        when(
          () => repo.register(email: 'op@x.com', password: validPassword),
        ).thenAnswer((_) async => tokens);
        return RegisterBloc(repo);
      },
      act: (b) => b.add(
        const RegisterSubmitted(
          email: 'op@x.com',
          password: validPassword,
          confirmPassword: validPassword,
        ),
      ),
      expect: () => const <RegisterState>[
        RegisterSubmitting(),
        RegisterSucceeded(tokens),
      ],
      verify: (_) {
        verify(
          () => repo.register(email: 'op@x.com', password: validPassword),
        ).called(1);
      },
    );

    blocTest<RegisterBloc, RegisterState>(
      'email vacío: no llama al repo, emite Failed(invalidInput)',
      build: () => RegisterBloc(repo),
      act: (b) => b.add(
        const RegisterSubmitted(
          email: '',
          password: validPassword,
          confirmPassword: validPassword,
        ),
      ),
      expect: () => const <RegisterState>[
        RegisterFailed(RegisterFailureKind.invalidInput),
      ],
      verify: (_) {
        verifyNever(
          () => repo.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      },
    );

    blocTest<RegisterBloc, RegisterState>(
      'password corta (<12): no llama al repo, emite Failed(passwordTooShort)',
      build: () => RegisterBloc(repo),
      act: (b) => b.add(
        const RegisterSubmitted(
          email: 'op@x.com',
          password: 'short',
          confirmPassword: 'short',
        ),
      ),
      expect: () => const <RegisterState>[
        RegisterFailed(RegisterFailureKind.passwordTooShort),
      ],
      verify: (_) {
        verifyNever(
          () => repo.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      },
    );

    blocTest<RegisterBloc, RegisterState>(
      'confirm distinta: no llama al repo, emite Failed(passwordMismatch)',
      build: () => RegisterBloc(repo),
      act: (b) => b.add(
        const RegisterSubmitted(
          email: 'op@x.com',
          password: validPassword,
          confirmPassword: 'otra-cosa-12c',
        ),
      ),
      expect: () => const <RegisterState>[
        RegisterFailed(RegisterFailureKind.passwordMismatch),
      ],
      verify: (_) {
        verifyNever(
          () => repo.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      },
    );

    blocTest<RegisterBloc, RegisterState>(
      '409: Submitting → Failed(emailTaken)',
      build: () {
        when(
          () => repo.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const EmailTakenFailure());
        return RegisterBloc(repo);
      },
      act: (b) => b.add(
        const RegisterSubmitted(
          email: 'op@x.com',
          password: validPassword,
          confirmPassword: validPassword,
        ),
      ),
      expect: () => const <RegisterState>[
        RegisterSubmitting(),
        RegisterFailed(RegisterFailureKind.emailTaken),
      ],
    );

    blocTest<RegisterBloc, RegisterState>(
      '400: Submitting → Failed(passwordTooShort) por WeakPassword del backend',
      build: () {
        when(
          () => repo.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const WeakPasswordFailure());
        return RegisterBloc(repo);
      },
      act: (b) => b.add(
        const RegisterSubmitted(
          email: 'op@x.com',
          password: validPassword,
          confirmPassword: validPassword,
        ),
      ),
      expect: () => const <RegisterState>[
        RegisterSubmitting(),
        RegisterFailed(RegisterFailureKind.passwordTooShort),
      ],
    );

    blocTest<RegisterBloc, RegisterState>(
      '429: Submitting → Failed(rateLimited)',
      build: () {
        when(
          () => repo.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const RateLimitedFailure());
        return RegisterBloc(repo);
      },
      act: (b) => b.add(
        const RegisterSubmitted(
          email: 'op@x.com',
          password: validPassword,
          confirmPassword: validPassword,
        ),
      ),
      expect: () => const <RegisterState>[
        RegisterSubmitting(),
        RegisterFailed(RegisterFailureKind.rateLimited),
      ],
    );

    blocTest<RegisterBloc, RegisterState>(
      'timeout: Submitting → Failed(network)',
      build: () {
        when(
          () => repo.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const NetworkFailure());
        return RegisterBloc(repo);
      },
      act: (b) => b.add(
        const RegisterSubmitted(
          email: 'op@x.com',
          password: validPassword,
          confirmPassword: validPassword,
        ),
      ),
      expect: () => const <RegisterState>[
        RegisterSubmitting(),
        RegisterFailed(RegisterFailureKind.network),
      ],
    );

    blocTest<RegisterBloc, RegisterState>(
      '5xx u otro: Submitting → Failed(unknown)',
      build: () {
        when(
          () => repo.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const UnknownAuthFailure());
        return RegisterBloc(repo);
      },
      act: (b) => b.add(
        const RegisterSubmitted(
          email: 'op@x.com',
          password: validPassword,
          confirmPassword: validPassword,
        ),
      ),
      expect: () => const <RegisterState>[
        RegisterSubmitting(),
        RegisterFailed(RegisterFailureKind.unknown),
      ],
    );
  });
}
