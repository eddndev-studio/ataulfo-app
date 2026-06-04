import 'package:ataulfo/features/invitations/data/datasources/invitations_datasource.dart';
import 'package:ataulfo/features/invitations/data/repositories/invitations_repository_impl.dart';
import 'package:ataulfo/features/invitations/domain/entities/invitation.dart';
import 'package:ataulfo/features/invitations/domain/failures/invitations_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements InvitationsDatasource {}

void main() {
  late _MockDs ds;
  late InvitationsRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    repo = InvitationsRepositoryImpl(datasource: ds);
  });

  test('list delega y devuelve la lista', () async {
    final items = <Invitation>[
      Invitation(
        id: 'i1',
        email: 'a@x.com',
        role: 'WORKER',
        status: 'PENDING',
        expiresAt: DateTime.utc(2026, 6, 1),
        createdAt: DateTime.utc(2026, 5, 25),
      ),
    ];
    when(() => ds.list()).thenAnswer((_) async => items);

    expect(await repo.list(), items);
    verify(() => ds.list()).called(1);
  });

  test('create delega con email y rol', () async {
    when(() => ds.create(any(), any())).thenAnswer((_) async {});

    await repo.create('a@x.com', 'ADMIN');

    verify(() => ds.create('a@x.com', 'ADMIN')).called(1);
  });

  test('cancel delega con id', () async {
    when(() => ds.cancel(any())).thenAnswer((_) async {});

    await repo.cancel('i1');

    verify(() => ds.cancel('i1')).called(1);
  });

  test('propaga la failure del datasource sin envolverla', () async {
    when(
      () => ds.create(any(), any()),
    ).thenThrow(const InvitationsDuplicateFailure());

    await expectLater(
      () => repo.create('a@x.com', 'ADMIN'),
      throwsA(isA<InvitationsDuplicateFailure>()),
    );
  });
}
