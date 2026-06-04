import 'package:ataulfo/features/auth/domain/entities/auth_tokens.dart';
import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/create_org_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

const _tokens = AuthTokens(
  accessToken: 'a',
  refreshToken: 'r',
  tokenType: 'Bearer',
  expiresInSeconds: 900,
);

void main() {
  group('CreateOrgCubit', () {
    test('estado inicial = CreateOrgIdle', () {
      expect(CreateOrgCubit(_MockAuthRepo()).state, const CreateOrgIdle());
    });

    blocTest<CreateOrgCubit, CreateOrgState>(
      'OK → [Creating, Created]',
      build: () {
        final repo = _MockAuthRepo();
        when(
          () => repo.createOrganization(any()),
        ).thenAnswer((_) async => _tokens);
        return CreateOrgCubit(repo);
      },
      act: (cubit) => cubit.create('Acme'),
      expect: () => const <CreateOrgState>[
        CreateOrgCreating(),
        CreateOrgCreated(),
      ],
      verify: (_) {},
    );

    blocTest<CreateOrgCubit, CreateOrgState>(
      'falla → [Creating, Failed(failure)]',
      build: () {
        final repo = _MockAuthRepo();
        when(
          () => repo.createOrganization(any()),
        ).thenThrow(const NetworkFailure());
        return CreateOrgCubit(repo);
      },
      act: (cubit) => cubit.create('Acme'),
      expect: () => const <CreateOrgState>[
        CreateOrgCreating(),
        CreateOrgFailed(NetworkFailure()),
      ],
    );
  });
}
