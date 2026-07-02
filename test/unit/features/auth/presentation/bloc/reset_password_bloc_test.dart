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
  const email = 'op@example.com';
  const code = '123456';

  ResetPasswordSubmitted submit({
    String e = email,
    String c = code,
    String p = validPassword,
  }) => ResetPasswordSubmitted(email: e, code: c, newPassword: p);

  group('ResetPasswordBloc', () {
    test('estado inicial es ResetPasswordInitial', () {
      expect(ResetPasswordBloc(repo).state, const ResetPasswordInitial());
    });

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'OK: Submitting → Succeeded y llama a resetPassword una vez',
      build: () {
        when(
          () => repo.resetPassword(
            email: email,
            code: code,
            newPassword: validPassword,
          ),
        ).thenAnswer((_) async {});
        return ResetPasswordBloc(repo);
      },
      act: (b) => b.add(submit()),
      expect: () => const <ResetPasswordState>[
        ResetPasswordSubmitting(),
        ResetPasswordSucceeded(),
      ],
      verify: (_) {
        verify(
          () => repo.resetPassword(
            email: email,
            code: code,
            newPassword: validPassword,
          ),
        ).called(1);
      },
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'recorta el correo antes de canjear',
      build: () {
        when(
          () => repo.resetPassword(
            email: email,
            code: code,
            newPassword: validPassword,
          ),
        ).thenAnswer((_) async {});
        return ResetPasswordBloc(repo);
      },
      act: (b) => b.add(submit(e: '  op@example.com  ')),
      expect: () => const <ResetPasswordState>[
        ResetPasswordSubmitting(),
        ResetPasswordSucceeded(),
      ],
      verify: (_) {
        verify(
          () => repo.resetPassword(
            email: email,
            code: code,
            newPassword: validPassword,
          ),
        ).called(1);
      },
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'correo sin arroba: NO llama al repo, emite Failed(invalidInput)',
      build: () => ResetPasswordBloc(repo),
      act: (b) => b.add(submit(e: 'no-arroba')),
      expect: () => const <ResetPasswordState>[
        ResetPasswordFailed(ResetPasswordFailureKind.invalidInput),
      ],
      verify: (_) {
        verifyNever(
          () => repo.resetPassword(
            email: any(named: 'email'),
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          ),
        );
      },
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'código != 6 dígitos: NO llama al repo, emite Failed(invalidCode)',
      build: () => ResetPasswordBloc(repo),
      act: (b) => b.add(submit(c: '123')),
      expect: () => const <ResetPasswordState>[
        ResetPasswordFailed(ResetPasswordFailureKind.invalidCode),
      ],
      verify: (_) {
        verifyNever(
          () => repo.resetPassword(
            email: any(named: 'email'),
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          ),
        );
      },
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'código con letras: emite Failed(invalidCode)',
      build: () => ResetPasswordBloc(repo),
      act: (b) => b.add(submit(c: '12a456')),
      expect: () => const <ResetPasswordState>[
        ResetPasswordFailed(ResetPasswordFailureKind.invalidCode),
      ],
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'password corta (<12): NO llama al repo, emite Failed(passwordTooShort)',
      build: () => ResetPasswordBloc(repo),
      act: (b) => b.add(submit(p: 'short')),
      expect: () => const <ResetPasswordState>[
        ResetPasswordFailed(ResetPasswordFailureKind.passwordTooShort),
      ],
      verify: (_) {
        verifyNever(
          () => repo.resetPassword(
            email: any(named: 'email'),
            code: any(named: 'code'),
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
            email: any(named: 'email'),
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(const WeakPasswordFailure());
        return ResetPasswordBloc(repo);
      },
      act: (b) => b.add(submit()),
      expect: () => const <ResetPasswordState>[
        ResetPasswordSubmitting(),
        ResetPasswordFailed(ResetPasswordFailureKind.passwordTooShort),
      ],
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      '404 InvalidToken: Submitting → Failed(invalidCode)',
      build: () {
        when(
          () => repo.resetPassword(
            email: any(named: 'email'),
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(const InvalidTokenFailure());
        return ResetPasswordBloc(repo);
      },
      act: (b) => b.add(submit()),
      expect: () => const <ResetPasswordState>[
        ResetPasswordSubmitting(),
        ResetPasswordFailed(ResetPasswordFailureKind.invalidCode),
      ],
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      '410 ExpiredToken: Submitting → Failed(expiredCode)',
      build: () {
        when(
          () => repo.resetPassword(
            email: any(named: 'email'),
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(const ExpiredTokenFailure());
        return ResetPasswordBloc(repo);
      },
      act: (b) => b.add(submit()),
      expect: () => const <ResetPasswordState>[
        ResetPasswordSubmitting(),
        ResetPasswordFailed(ResetPasswordFailureKind.expiredCode),
      ],
    );

    blocTest<ResetPasswordBloc, ResetPasswordState>(
      'timeout: Submitting → Failed(network)',
      build: () {
        when(
          () => repo.resetPassword(
            email: any(named: 'email'),
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(const NetworkFailure());
        return ResetPasswordBloc(repo);
      },
      act: (b) => b.add(submit()),
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
            email: any(named: 'email'),
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(const UnknownAuthFailure());
        return ResetPasswordBloc(repo);
      },
      act: (b) => b.add(submit()),
      expect: () => const <ResetPasswordState>[
        ResetPasswordSubmitting(),
        ResetPasswordFailed(ResetPasswordFailureKind.unknown),
      ],
    );
  });
}
