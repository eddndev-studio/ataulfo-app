import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/rename_org_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

void main() {
  group('RenameOrgCubit', () {
    test('estado inicial = RenameOrgIdle', () {
      expect(RenameOrgCubit(_MockAuthRepo()).state, const RenameOrgIdle());
    });

    blocTest<RenameOrgCubit, RenameOrgState>(
      'OK → [Renaming, Renamed] y delega con el nombre',
      build: () {
        final repo = _MockAuthRepo();
        when(() => repo.renameOrganization(any())).thenAnswer((_) async {});
        return RenameOrgCubit(repo);
      },
      act: (cubit) => cubit.rename('Nuevo'),
      expect: () => const <RenameOrgState>[
        RenameOrgRenaming(),
        RenameOrgRenamed(),
      ],
      verify: (_) {},
    );

    blocTest<RenameOrgCubit, RenameOrgState>(
      'falla → [Renaming, Failed(failure)]',
      build: () {
        final repo = _MockAuthRepo();
        when(
          () => repo.renameOrganization(any()),
        ).thenThrow(const NetworkFailure());
        return RenameOrgCubit(repo);
      },
      act: (cubit) => cubit.rename('Nuevo'),
      expect: () => const <RenameOrgState>[
        RenameOrgRenaming(),
        RenameOrgFailed(NetworkFailure()),
      ],
    );

    blocTest<RenameOrgCubit, RenameOrgState>(
      'reintento tras Failed vuelve a pasar por Renaming',
      build: () {
        final repo = _MockAuthRepo();
        when(
          () => repo.renameOrganization(any()),
        ).thenThrow(const UnknownAuthFailure());
        return RenameOrgCubit(repo);
      },
      seed: () => const RenameOrgFailed(UnknownAuthFailure()),
      act: (cubit) => cubit.rename('Otro'),
      expect: () => const <RenameOrgState>[
        RenameOrgRenaming(),
        RenameOrgFailed(UnknownAuthFailure()),
      ],
    );
  });
}
