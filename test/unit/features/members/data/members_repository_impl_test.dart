import 'package:ataulfo/features/members/data/datasources/members_datasource.dart';
import 'package:ataulfo/features/members/data/repositories/members_repository_impl.dart';
import 'package:ataulfo/features/members/domain/entities/member.dart';
import 'package:ataulfo/features/members/domain/failures/members_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements MembersDatasource {}

void main() {
  late _MockDs ds;
  late MembersRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    repo = MembersRepositoryImpl(datasource: ds);
  });

  group('MembersRepositoryImpl.list', () {
    test('delega al datasource y devuelve la lista', () async {
      const items = <Member>[
        Member(
          id: 'm1',
          userId: 'u1',
          email: 'a@x.com',
          emailVerified: true,
          role: 'OWNER',
        ),
      ];
      when(() => ds.list()).thenAnswer((_) async => items);

      final got = await repo.list();

      expect(got, items);
      verify(() => ds.list()).called(1);
    });

    test('propaga la failure del datasource sin envolverla', () async {
      when(() => ds.list()).thenThrow(const MembersForbiddenFailure());

      await expectLater(
        () => repo.list(),
        throwsA(isA<MembersForbiddenFailure>()),
      );
    });
  });
}
