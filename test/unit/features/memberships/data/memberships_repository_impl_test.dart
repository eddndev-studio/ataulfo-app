import 'package:ataulfo/features/memberships/data/datasources/memberships_datasource.dart';
import 'package:ataulfo/features/memberships/data/repositories/memberships_repository_impl.dart';
import 'package:ataulfo/features/memberships/domain/entities/membership.dart';
import 'package:ataulfo/features/memberships/domain/failures/memberships_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements MembershipsDatasource {}

void main() {
  late _MockDs ds;
  late MembershipsRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    repo = MembershipsRepositoryImpl(datasource: ds);
  });

  group('MembershipsRepositoryImpl.list', () {
    test('delega al datasource y devuelve la lista', () async {
      const items = <Membership>[
        Membership(orgId: 'o1', orgName: 'Acme', role: 'OWNER'),
      ];
      when(() => ds.list()).thenAnswer((_) async => items);

      final got = await repo.list();

      expect(got, items);
      verify(() => ds.list()).called(1);
    });

    test('propaga la failure del datasource sin envolverla', () async {
      when(() => ds.list()).thenThrow(const MembershipsNetworkFailure());

      // Closure: mocktail.thenThrow lanza sync al invocarse; expectLater
      // necesita una función para atrapar sync-throws igual que async.
      await expectLater(
        () => repo.list(),
        throwsA(isA<MembershipsNetworkFailure>()),
      );
    });
  });
}
