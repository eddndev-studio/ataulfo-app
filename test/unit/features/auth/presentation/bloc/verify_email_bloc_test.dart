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

  group('VerifyEmailBloc', () {
    test('estado inicial es VerifyEmailInitial', () {
      expect(VerifyEmailBloc(repo).state, const VerifyEmailInitial());
    });

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      'token en blanco: NO llama al repo, emite Failed(invalidInput)',
      build: () => VerifyEmailBloc(repo),
      act: (b) => b.add(const VerifyEmailSubmitted('   ')),
      expect: () => const <VerifyEmailState>[
        VerifyEmailFailed(VerifyEmailFailureKind.invalidInput),
      ],
      verify: (_) {
        verifyNever(() => repo.verifyEmail(any()));
      },
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      'verifyEmail=false (verificado ahora): Submitting → Succeeded(false)',
      build: () {
        when(() => repo.verifyEmail('tok123')).thenAnswer((_) async => false);
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(const VerifyEmailSubmitted('tok123')),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailSucceeded(alreadyVerified: false),
      ],
      verify: (_) {
        verify(() => repo.verifyEmail('tok123')).called(1);
      },
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      'verifyEmail=true (ya estaba verificado): Submitting → Succeeded(true)',
      build: () {
        when(() => repo.verifyEmail('tok123')).thenAnswer((_) async => true);
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(const VerifyEmailSubmitted('tok123')),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailSucceeded(alreadyVerified: true),
      ],
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      'URL completa: extrae el token del query antes de canjear',
      build: () {
        when(() => repo.verifyEmail('tok123')).thenAnswer((_) async => false);
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(
        const VerifyEmailSubmitted('https://ataulfo.app/verify?token=tok123'),
      ),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailSucceeded(alreadyVerified: false),
      ],
      verify: (_) {
        verify(() => repo.verifyEmail('tok123')).called(1);
      },
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      '404 InvalidToken: Submitting → Failed(invalidLink)',
      build: () {
        when(
          () => repo.verifyEmail(any()),
        ).thenThrow(const InvalidTokenFailure());
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(const VerifyEmailSubmitted('tok123')),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailFailed(VerifyEmailFailureKind.invalidLink),
      ],
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      '410 ExpiredToken: Submitting → Failed(expiredLink)',
      build: () {
        when(
          () => repo.verifyEmail(any()),
        ).thenThrow(const ExpiredTokenFailure());
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(const VerifyEmailSubmitted('tok123')),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailFailed(VerifyEmailFailureKind.expiredLink),
      ],
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      'timeout: Submitting → Failed(network)',
      build: () {
        when(() => repo.verifyEmail(any())).thenThrow(const NetworkFailure());
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(const VerifyEmailSubmitted('tok123')),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailFailed(VerifyEmailFailureKind.network),
      ],
    );

    blocTest<VerifyEmailBloc, VerifyEmailState>(
      '5xx u otro: Submitting → Failed(unknown)',
      build: () {
        when(
          () => repo.verifyEmail(any()),
        ).thenThrow(const UnknownAuthFailure());
        return VerifyEmailBloc(repo);
      },
      act: (b) => b.add(const VerifyEmailSubmitted('tok123')),
      expect: () => const <VerifyEmailState>[
        VerifyEmailSubmitting(),
        VerifyEmailFailed(VerifyEmailFailureKind.unknown),
      ],
    );
  });
}
