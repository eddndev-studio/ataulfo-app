import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/accept_invitation_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  group('AcceptInvitationCubit', () {
    test('estado inicial es AcceptInvitationIdle', () {
      expect(AcceptInvitationCubit(repo).state, const AcceptInvitationIdle());
    });

    blocTest<AcceptInvitationCubit, AcceptInvitationState>(
      'token en blanco: NO llama al repo, emite Failed(invalidInput)',
      build: () => AcceptInvitationCubit(repo),
      act: (c) => c.accept('   '),
      expect: () => const <AcceptInvitationState>[
        AcceptInvitationFailed(AcceptInvitationFailureKind.invalidInput),
      ],
      verify: (_) {
        verifyNever(() => repo.acceptInvitation(any()));
      },
    );

    blocTest<AcceptInvitationCubit, AcceptInvitationState>(
      'URL completa: extrae el token del query antes de aceptar',
      build: () {
        when(() => repo.acceptInvitation('tok123')).thenAnswer((_) async {});
        return AcceptInvitationCubit(repo);
      },
      act: (c) => c.accept('https://ataulfo.app/invite?token=tok123'),
      expect: () => const <AcceptInvitationState>[
        AcceptInvitationAccepting(),
        AcceptInvitationAccepted(),
      ],
      verify: (_) {
        verify(() => repo.acceptInvitation('tok123')).called(1);
      },
    );

    blocTest<AcceptInvitationCubit, AcceptInvitationState>(
      'éxito (204): Accepting → Accepted',
      build: () {
        when(() => repo.acceptInvitation('tok123')).thenAnswer((_) async {});
        return AcceptInvitationCubit(repo);
      },
      act: (c) => c.accept('tok123'),
      expect: () => const <AcceptInvitationState>[
        AcceptInvitationAccepting(),
        AcceptInvitationAccepted(),
      ],
      verify: (_) {
        verify(() => repo.acceptInvitation('tok123')).called(1);
      },
    );

    blocTest<AcceptInvitationCubit, AcceptInvitationState>(
      '404 InvalidToken: Accepting → Failed(invalidToken)',
      build: () {
        when(
          () => repo.acceptInvitation(any()),
        ).thenThrow(const InvalidTokenFailure());
        return AcceptInvitationCubit(repo);
      },
      act: (c) => c.accept('tok123'),
      expect: () => const <AcceptInvitationState>[
        AcceptInvitationAccepting(),
        AcceptInvitationFailed(AcceptInvitationFailureKind.invalidToken),
      ],
    );

    blocTest<AcceptInvitationCubit, AcceptInvitationState>(
      '410 ExpiredToken: Accepting → Failed(invalidToken) '
      '(accept no mapea 410, pero el switch es exhaustivo)',
      build: () {
        when(
          () => repo.acceptInvitation(any()),
        ).thenThrow(const ExpiredTokenFailure());
        return AcceptInvitationCubit(repo);
      },
      act: (c) => c.accept('tok123'),
      expect: () => const <AcceptInvitationState>[
        AcceptInvitationAccepting(),
        AcceptInvitationFailed(AcceptInvitationFailureKind.invalidToken),
      ],
    );

    blocTest<AcceptInvitationCubit, AcceptInvitationState>(
      '409 EmailMismatch (correo distinto o ya miembro): '
      'Accepting → Failed(emailMismatch)',
      build: () {
        when(
          () => repo.acceptInvitation(any()),
        ).thenThrow(const EmailMismatchFailure());
        return AcceptInvitationCubit(repo);
      },
      act: (c) => c.accept('tok123'),
      expect: () => const <AcceptInvitationState>[
        AcceptInvitationAccepting(),
        AcceptInvitationFailed(AcceptInvitationFailureKind.emailMismatch),
      ],
    );

    blocTest<AcceptInvitationCubit, AcceptInvitationState>(
      '403 EmailNotVerified: Accepting → Failed(emailNotVerified)',
      build: () {
        when(
          () => repo.acceptInvitation(any()),
        ).thenThrow(const EmailNotVerifiedFailure());
        return AcceptInvitationCubit(repo);
      },
      act: (c) => c.accept('tok123'),
      expect: () => const <AcceptInvitationState>[
        AcceptInvitationAccepting(),
        AcceptInvitationFailed(AcceptInvitationFailureKind.emailNotVerified),
      ],
    );

    blocTest<AcceptInvitationCubit, AcceptInvitationState>(
      'timeout: Accepting → Failed(network)',
      build: () {
        when(
          () => repo.acceptInvitation(any()),
        ).thenThrow(const NetworkFailure());
        return AcceptInvitationCubit(repo);
      },
      act: (c) => c.accept('tok123'),
      expect: () => const <AcceptInvitationState>[
        AcceptInvitationAccepting(),
        AcceptInvitationFailed(AcceptInvitationFailureKind.network),
      ],
    );

    blocTest<AcceptInvitationCubit, AcceptInvitationState>(
      '5xx u otro: Accepting → Failed(unknown)',
      build: () {
        when(
          () => repo.acceptInvitation(any()),
        ).thenThrow(const UnknownAuthFailure());
        return AcceptInvitationCubit(repo);
      },
      act: (c) => c.accept('tok123'),
      expect: () => const <AcceptInvitationState>[
        AcceptInvitationAccepting(),
        AcceptInvitationFailed(AcceptInvitationFailureKind.unknown),
      ],
    );
  });
}
