import 'package:ataulfo/features/invitations/data/datasources/invitations_datasource.dart';
import 'package:ataulfo/features/invitations/data/repositories/invitations_repository_impl.dart';
import 'package:ataulfo/features/invitations/domain/entities/created_invitation.dart';
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

  test('create delega y devuelve el CreatedInvitation', () async {
    when(() => ds.create(any(), any(), any())).thenAnswer(
      (_) async => const CreatedInvitation(
        email: 'a@x.com',
        token: 'RAW-T',
        emailSent: true,
      ),
    );

    final created = await repo.create('a@x.com', 'WORKER', const <String>[
      'b1',
    ]);

    expect(created.token, 'RAW-T');
    expect(created.emailSent, isTrue);
    verify(
      () => ds.create('a@x.com', 'WORKER', const <String>['b1']),
    ).called(1);
  });

  test('cancel delega con id', () async {
    when(() => ds.cancel(any())).thenAnswer((_) async {});

    await repo.cancel('i1');

    verify(() => ds.cancel('i1')).called(1);
  });

  test('propaga la failure del datasource sin envolverla', () async {
    when(
      () => ds.create(any(), any(), any()),
    ).thenThrow(const InvitationsDuplicateFailure());

    await expectLater(
      () => repo.create('a@x.com', 'ADMIN', const <String>[]),
      throwsA(isA<InvitationsDuplicateFailure>()),
    );
  });
}
