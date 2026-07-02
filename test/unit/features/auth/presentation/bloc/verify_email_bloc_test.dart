import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/verify_email_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  const email = 'op@example.com';
  const code = '123456';

  VerifyEmailSubmitted submit({String e = email, String c = code}) =>
      VerifyEmailSubmitted(email: e, code: c);

  group('VerifyEmailBloc', () {
    test('estado inicial es VerifyEmailInitial', () {
      expect(VerifyEmailBloc(repo).state, const VerifyEmailInitial());
    });

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      'correo sin arroba: NO llama al repo, emite Failed(invalidInput)',
      build: () => VerifyEmailBloc(repo),
      act: (b) => b.add(submit(e: 'no-arroba')),
      expect: () => const <VerifyEmailState>[
        VerifyEmailFailed(VerifyEmailFailureKind.invalidInput),
      ],
      verify: (_) {
        verifyNever(
          () => repo.verifyEmail(
            email: any(named: 'email'),
            code: any(named: 'code'),
          ),
        );
      },
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      'código != 6 dígitos: NO llama al repo, emite Failed(invalidCode)',
      build: () => VerifyEmailBloc(repo),
      act: (b) => b.add(submit(c: '12')),
      expect: () => const <VerifyEmailState>[
        VerifyEmailFailed(VerifyEmailFailureKind.invalidCode),
      ],
      verify: (_) {
        verifyNever(
          () => repo.verifyEmail(
            email: any(named: 'email'),
            code: any(named: 'code'),
          ),
        );
      },
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      'verifyEmail=false (verificado ahora): Submitting → Succeeded(false)',
      build: () {
        when(
          () => repo.verifyEmail(email: email, code: code),
        ).thenAnswer((_) async => false);
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(submit()),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailSucceeded(alreadyVerified: false),
      ],
      verify: (_) {
        verify(() => repo.verifyEmail(email: email, code: code)).called(1);
      },
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      'verifyEmail=true (ya estaba verificado): Submitting → Succeeded(true)',
      build: () {
        when(
          () => repo.verifyEmail(email: email, code: code),
        ).thenAnswer((_) async => true);
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(submit()),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailSucceeded(alreadyVerified: true),
      ],
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      'recorta el correo antes de canjear',
      build: () {
        when(
          () => repo.verifyEmail(email: email, code: code),
        ).thenAnswer((_) async => false);
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(submit(e: '  op@example.com  ')),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailSucceeded(alreadyVerified: false),
      ],
      verify: (_) {
        verify(() => repo.verifyEmail(email: email, code: code)).called(1);
      },
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      '404 InvalidToken: Submitting → Failed(invalidCode)',
      build: () {
        when(
          () => repo.verifyEmail(
            email: any(named: 'email'),
            code: any(named: 'code'),
          ),
        ).thenThrow(const InvalidTokenFailure());
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(submit()),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailFailed(VerifyEmailFailureKind.invalidCode),
      ],
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      '410 ExpiredToken: Submitting → Failed(expiredCode)',
      build: () {
        when(
          () => repo.verifyEmail(
            email: any(named: 'email'),
            code: any(named: 'code'),
          ),
        ).thenThrow(const ExpiredTokenFailure());
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(submit()),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailFailed(VerifyEmailFailureKind.expiredCode),
      ],
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      'timeout: Submitting → Failed(network)',
      build: () {
        when(
          () => repo.verifyEmail(
            email: any(named: 'email'),
            code: any(named: 'code'),
          ),
        ).thenThrow(const NetworkFailure());
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(submit()),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailFailed(VerifyEmailFailureKind.network),
      ],
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      '429 RateLimited: Submitting → Failed(rateLimited)',
      build: () {
        when(
          () => repo.verifyEmail(
            email: any(named: 'email'),
            code: any(named: 'code'),
          ),
        ).thenThrow(const RateLimitedFailure());
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(submit()),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailFailed(VerifyEmailFailureKind.rateLimited),
      ],
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      '5xx u otro: Submitting → Failed(unknown)',
      build: () {
        when(
          () => repo.verifyEmail(
            email: any(named: 'email'),
            code: any(named: 'code'),
          ),
        ).thenThrow(const UnknownAuthFailure());
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(submit()),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailFailed(VerifyEmailFailureKind.unknown),
      ],
    );
  });
}
