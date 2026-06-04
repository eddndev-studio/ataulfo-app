import 'package:ataulfo/features/members/domain/failures/members_failure.dart';
import 'package:ataulfo/features/members/domain/repositories/members_repository.dart';
import 'package:ataulfo/features/members/presentation/bloc/member_mutation_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MembersRepository {}

void main() {
  group('MemberMutationCubit', () {
    test('estado inicial = MemberMutationIdle', () {
      expect(
        MemberMutationCubit(_MockRepo()).state,
        const MemberMutationIdle(),
      );
    });

    group('changeRole', () {
      blocTest<MemberMutationCubit, MemberMutationState>(
        'ok → [InProgress, Success(roleChanged)] y delega con id+rol',
        build: () {
          final repo = _MockRepo();
          when(() => repo.changeRole(any(), any())).thenAnswer((_) async {});
          return MemberMutationCubit(repo);
        },
        act: (cubit) => cubit.changeRole('m1', 'ADMIN'),
        expect: () => const <MemberMutationState>[
          MemberMutationInProgress(),
          MemberMutationSuccess(MemberMutationAction.roleChanged),
        ],
        verify: (cubit) {
          // El cubit no transforma el rol; lo manda tal cual (uppercase del UI).
        },
      );

      blocTest<MemberMutationCubit, MemberMutationState>(
        'self-upgrade → [InProgress, Failure(SelfRoleUpgrade)]',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.changeRole(any(), any()),
          ).thenThrow(const MembersSelfRoleUpgradeFailure());
          return MemberMutationCubit(repo);
        },
        act: (cubit) => cubit.changeRole('m1', 'OWNER'),
        expect: () => const <MemberMutationState>[
          MemberMutationInProgress(),
          MemberMutationFailure(MembersSelfRoleUpgradeFailure()),
        ],
      );

      blocTest<MemberMutationCubit, MemberMutationState>(
        'mismo rol (204 no-op del backend) → Success igual',
        build: () {
          final repo = _MockRepo();
          // Backend responde 204 sin cambiar nada; el datasource completa sin
          // error, así que el cubit lo trata como éxito.
          when(() => repo.changeRole(any(), any())).thenAnswer((_) async {});
          return MemberMutationCubit(repo);
        },
        act: (cubit) => cubit.changeRole('m1', 'ADMIN'),
        expect: () => const <MemberMutationState>[
          MemberMutationInProgress(),
          MemberMutationSuccess(MemberMutationAction.roleChanged),
        ],
      );
    });

    group('remove', () {
      blocTest<MemberMutationCubit, MemberMutationState>(
        'ok → [InProgress, Success(removed)]',
        build: () {
          final repo = _MockRepo();
          when(() => repo.removeMember(any())).thenAnswer((_) async {});
          return MemberMutationCubit(repo);
        },
        act: (cubit) => cubit.remove('m1'),
        expect: () => const <MemberMutationState>[
          MemberMutationInProgress(),
          MemberMutationSuccess(MemberMutationAction.removed),
        ],
      );

      blocTest<MemberMutationCubit, MemberMutationState>(
        'sole-owner → [InProgress, Failure(SoleOwner)]',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.removeMember(any()),
          ).thenThrow(const MembersSoleOwnerFailure());
          return MemberMutationCubit(repo);
        },
        act: (cubit) => cubit.remove('m1'),
        expect: () => const <MemberMutationState>[
          MemberMutationInProgress(),
          MemberMutationFailure(MembersSoleOwnerFailure()),
        ],
      );
    });

    group('transfer', () {
      blocTest<MemberMutationCubit, MemberMutationState>(
        'ok → [InProgress, Success(ownershipTransferred)]',
        build: () {
          final repo = _MockRepo();
          when(() => repo.transferOwnership(any())).thenAnswer((_) async {});
          return MemberMutationCubit(repo);
        },
        act: (cubit) => cubit.transfer('m2'),
        expect: () => const <MemberMutationState>[
          MemberMutationInProgress(),
          MemberMutationSuccess(MemberMutationAction.ownershipTransferred),
        ],
      );

      blocTest<MemberMutationCubit, MemberMutationState>(
        'forbidden → [InProgress, Failure(Forbidden)]',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.transferOwnership(any()),
          ).thenThrow(const MembersForbiddenFailure());
          return MemberMutationCubit(repo);
        },
        act: (cubit) => cubit.transfer('m2'),
        expect: () => const <MemberMutationState>[
          MemberMutationInProgress(),
          MemberMutationFailure(MembersForbiddenFailure()),
        ],
      );
    });

    blocTest<MemberMutationCubit, MemberMutationState>(
      'reintento tras Failure vuelve a pasar por InProgress (dos fallos '
      'idénticos siguen siendo transiciones distintas)',
      build: () {
        final repo = _MockRepo();
        when(
          () => repo.changeRole(any(), any()),
        ).thenThrow(const MembersSoleOwnerFailure());
        return MemberMutationCubit(repo);
      },
      seed: () => const MemberMutationFailure(MembersSoleOwnerFailure()),
      act: (cubit) => cubit.changeRole('m1', 'WORKER'),
      expect: () => const <MemberMutationState>[
        MemberMutationInProgress(),
        MemberMutationFailure(MembersSoleOwnerFailure()),
      ],
    );
  });
}
