import 'package:ataulfo/features/auth/domain/entities/auth_tokens.dart';
import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/switch_org_cubit.dart';
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
  late _MockAuthRepo repo;

  setUp(() => repo = _MockAuthRepo());

  test('estado inicial es Idle', () {
    expect(SwitchOrgCubit(repo).state, const SwitchOrgIdle());
  });

  blocTest<SwitchOrgCubit, SwitchOrgState>(
    'switchTo persiste vía repo y emite Switching → Switched(orgId)',
    build: () {
      when(() => repo.switchOrg('o-2')).thenAnswer((_) async => _tokens);
      return SwitchOrgCubit(repo);
    },
    act: (cubit) => cubit.switchTo('o-2'),
    expect: () => const <SwitchOrgState>[
      SwitchOrgSwitching(),
      SwitchOrgSwitched('o-2'),
    ],
    verify: (_) => verify(() => repo.switchOrg('o-2')).called(1),
  );

  blocTest<SwitchOrgCubit, SwitchOrgState>(
    'NotMemberFailure colapsa a Failed llevando el failure (la página '
    'distingue para recargar la lista)',
    build: () {
      when(
        () => repo.switchOrg('o-gone'),
      ).thenThrow(const NotMemberFailure());
      return SwitchOrgCubit(repo);
    },
    act: (cubit) => cubit.switchTo('o-gone'),
    expect: () => const <SwitchOrgState>[
      SwitchOrgSwitching(),
      SwitchOrgFailed(NotMemberFailure()),
    ],
  );

  blocTest<SwitchOrgCubit, SwitchOrgState>(
    'un fallo genérico también colapsa a Failed con su failure',
    build: () {
      when(() => repo.switchOrg('o-2')).thenThrow(const NetworkFailure());
      return SwitchOrgCubit(repo);
    },
    act: (cubit) => cubit.switchTo('o-2'),
    expect: () => const <SwitchOrgState>[
      SwitchOrgSwitching(),
      SwitchOrgFailed(NetworkFailure()),
    ],
  );

  group('igualdad de estados', () {
    test('Failed compara por failure', () {
      expect(
        const SwitchOrgFailed(NotMemberFailure()),
        const SwitchOrgFailed(NotMemberFailure()),
      );
      expect(
        const SwitchOrgFailed(NotMemberFailure()),
        isNot(const SwitchOrgFailed(NetworkFailure())),
      );
    });

    test('Switched compara por orgId', () {
      expect(const SwitchOrgSwitched('o-1'), const SwitchOrgSwitched('o-1'));
      expect(
        const SwitchOrgSwitched('o-1'),
        isNot(const SwitchOrgSwitched('o-2')),
      );
    });
  });
}
