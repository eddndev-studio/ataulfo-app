import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/reset_password_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  // 12+ chars: satisface el mínimo de cliente que evita un viaje al backend.
  const validPassword = 'hunter2-secret';

  group('ResetPasswordBloc', () {
    test('estado inicial es ResetPasswordInitial', () {
      expect(ResetPasswordBloc(repo).state, const ResetPasswordInitial());
    });

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'OK con token crudo: Submitting → Succeeded y llama a resetPassword una vez',
      build: () {
        when(
          () => repo.resetPassword(token: 'tok123', newPassword: validPassword),
        ).thenAnswer((_) async {});
        return ResetPasswordBloc(repo);
      },
      act: (b) => b.add(
        const ResetPasswordSubmitted(
          pastedLinkOrToken: 'tok123',
          newPassword: validPassword,
        ),
      ),
      expect: () => const <ResetPasswordState>[
        ResetPasswordSubmitting(),
        ResetPasswordSucceeded(),
      ],
      verify: (_) {
        verify(
          () => repo.resetPassword(token: 'tok123', newPassword: validPassword),
        ).called(1);
      },
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'OK con URL completa: extrae el token del query antes de canjear',
      build: () {
        when(
          () => repo.resetPassword(token: 'tok123', newPassword: validPassword),
        ).thenAnswer((_) async {});
        return ResetPasswordBloc(repo);
      },
      act: (b) => b.add(
        const ResetPasswordSubmitted(
          pastedLinkOrToken: 'https://ataulfo.app/reset?token=tok123',
          newPassword: validPassword,
        ),
      ),
      expect: () => const <ResetPasswordState>[
        ResetPasswordSubmitting(),
        ResetPasswordSucceeded(),
      ],
      verify: (_) {
        verify(
          () => repo.resetPassword(token: 'tok123', newPassword: validPassword),
        ).called(1);
      },
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'token en blanco: NO llama al repo, emite Failed(invalidInput)',
      build: () => ResetPasswordBloc(repo),
      act: (b) => b.add(
        const ResetPasswordSubmitted(
          pastedLinkOrToken: '   ',
          newPassword: validPassword,
        ),
      ),
      expect: () => const <ResetPasswordState>[
        ResetPasswordFailed(ResetPasswordFailureKind.invalidInput),
      ],
      verify: (_) {
        verifyNever(
          () => repo.resetPassword(
            token: any(named: 'token'),
            newPassword: any(named: 'newPassword'),
          ),
        );
      },
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'password corta (<12): NO llama al repo, emite Failed(passwordTooShort)',
      build: () => ResetPasswordBloc(repo),
      act: (b) => b.add(
        const ResetPasswordSubmitted(
          pastedLinkOrToken: 'tok123',
          newPassword: 'short',
        ),
      ),
      expect: () => const <ResetPasswordState>[
        ResetPasswordFailed(ResetPasswordFailureKind.passwordTooShort),
      ],
      verify: (_) {
        verifyNever(
          () => repo.resetPassword(
            token: any(named: 'token'),
            newPassword: any(named: 'newPassword'),
          ),
        );
      },
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      '400 WeakPassword del backend: Submitting → Failed(passwordTooShort)',
      build: () {
        when(
          () => repo.resetPassword(
            token: any(named: 'token'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(const WeakPasswordFailure());
        return ResetPasswordBloc(repo);
      },
      act: (b) => b.add(
        const ResetPasswordSubmitted(
          pastedLinkOrToken: 'tok123',
          newPassword: validPassword,
        ),
      ),
      expect: () => const <ResetPasswordState>[
        ResetPasswordSubmitting(),
        ResetPasswordFailed(ResetPasswordFailureKind.passwordTooShort),
      ],
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      '404 InvalidToken: Submitting → Failed(invalidLink)',
      build: () {
        when(
          () => repo.resetPassword(
            token: any(named: 'token'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(const InvalidTokenFailure());
        return ResetPasswordBloc(repo);
      },
      act: (b) => b.add(
        const ResetPasswordSubmitted(
          pastedLinkOrToken: 'tok123',
          newPassword: validPassword,
        ),
      ),
      expect: () => const <ResetPasswordState>[
        ResetPasswordSubmitting(),
        ResetPasswordFailed(ResetPasswordFailureKind.invalidLink),
      ],
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      '410 ExpiredToken: Submitting → Failed(expiredLink)',
      build: () {
        when(
          () => repo.resetPassword(
            token: any(named: 'token'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(const ExpiredTokenFailure());
        return ResetPasswordBloc(repo);
      },
      act: (b) => b.add(
        const ResetPasswordSubmitted(
          pastedLinkOrToken: 'tok123',
          newPassword: validPassword,
        ),
      ),
      expect: () => const <ResetPasswordState>[
        ResetPasswordSubmitting(),
        ResetPasswordFailed(ResetPasswordFailureKind.expiredLink),
      ],
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'timeout: Submitting → Failed(network)',
      build: () {
        when(
          () => repo.resetPassword(
            token: any(named: 'token'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(const NetworkFailure());
        return ResetPasswordBloc(repo);
      },
      act: (b) => b.add(
        const ResetPasswordSubmitted(
          pastedLinkOrToken: 'tok123',
          newPassword: validPassword,
        ),
      ),
      expect: () => const <ResetPasswordState>[
        ResetPasswordSubmitting(),
        ResetPasswordFailed(ResetPasswordFailureKind.network),
      ],
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      '5xx u otro: Submitting → Failed(unknown)',
      build: () {
        when(
          () => repo.resetPassword(
            token: any(named: 'token'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(const UnknownAuthFailure());
        return ResetPasswordBloc(repo);
      },
      act: (b) => b.add(
        const ResetPasswordSubmitted(
          pastedLinkOrToken: 'tok123',
          newPassword: validPassword,
        ),
      ),
      expect: () => const <ResetPasswordState>[
        ResetPasswordSubmitting(),
        ResetPasswordFailed(ResetPasswordFailureKind.unknown),
      ],
    );
  });
}
