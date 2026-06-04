import 'package:ataulfo/features/invitations/domain/failures/invitations_failure.dart';
import 'package:ataulfo/features/invitations/domain/repositories/invitations_repository.dart';
import 'package:ataulfo/features/invitations/presentation/bloc/invitation_mutation_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements InvitationsRepository {}

void main() {
  group('InvitationMutationCubit', () {
    test('estado inicial = Idle', () {
      expect(
        InvitationMutationCubit(_MockRepo()).state,
        const InvitationMutationIdle(),
      );
    });

    group('create', () {
      blocTest<InvitationMutationCubit, InvitationMutationState>(
        'ok → [InProgress, Success(created, email)] y delega con email+rol',
        build: () {
          final repo = _MockRepo();
          when(() => repo.create(any(), any())).thenAnswer((_) async {});
          return InvitationMutationCubit(repo);
        },
        act: (cubit) => cubit.create('a@x.com', 'WORKER'),
        expect: () => const <InvitationMutationState>[
          InvitationMutationInProgress(),
          InvitationMutationSuccess(
            InvitationMutationAction.created,
            email: 'a@x.com',
          ),
        ],
        verify: (_) {},
      );

      blocTest<InvitationMutationCubit, InvitationMutationState>(
        'duplicada → [InProgress, Failure(Duplicate)]',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.create(any(), any()),
          ).thenThrow(const InvitationsDuplicateFailure());
          return InvitationMutationCubit(repo);
        },
        act: (cubit) => cubit.create('a@x.com', 'WORKER'),
        expect: () => const <InvitationMutationState>[
          InvitationMutationInProgress(),
          InvitationMutationFailure(InvitationsDuplicateFailure()),
        ],
      );

      blocTest<InvitationMutationCubit, InvitationMutationState>(
        'validación → [InProgress, Failure(Validation)]',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.create(any(), any()),
          ).thenThrow(const InvitationsValidationFailure());
          return InvitationMutationCubit(repo);
        },
        act: (cubit) => cubit.create('mal', 'WORKER'),
        expect: () => const <InvitationMutationState>[
          InvitationMutationInProgress(),
          InvitationMutationFailure(InvitationsValidationFailure()),
        ],
      );
    });

    group('cancel', () {
      blocTest<InvitationMutationCubit, InvitationMutationState>(
        'ok → [InProgress, Success(canceled)]',
        build: () {
          final repo = _MockRepo();
          when(() => repo.cancel(any())).thenAnswer((_) async {});
          return InvitationMutationCubit(repo);
        },
        act: (cubit) => cubit.cancel('i1'),
        expect: () => const <InvitationMutationState>[
          InvitationMutationInProgress(),
          InvitationMutationSuccess(InvitationMutationAction.canceled),
        ],
      );

      blocTest<InvitationMutationCubit, InvitationMutationState>(
        'gone → [InProgress, Failure(Gone)]',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.cancel(any()),
          ).thenThrow(const InvitationsGoneFailure());
          return InvitationMutationCubit(repo);
        },
        act: (cubit) => cubit.cancel('i1'),
        expect: () => const <InvitationMutationState>[
          InvitationMutationInProgress(),
          InvitationMutationFailure(InvitationsGoneFailure()),
        ],
      );

      blocTest<InvitationMutationCubit, InvitationMutationState>(
        'not-found → [InProgress, Failure(NotFound)]',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.cancel(any()),
          ).thenThrow(const InvitationsNotFoundFailure());
          return InvitationMutationCubit(repo);
        },
        act: (cubit) => cubit.cancel('i1'),
        expect: () => const <InvitationMutationState>[
          InvitationMutationInProgress(),
          InvitationMutationFailure(InvitationsNotFoundFailure()),
        ],
      );
    });
  });
}
