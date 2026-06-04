import 'package:ataulfo/features/invitations/domain/entities/invitation.dart';
import 'package:ataulfo/features/invitations/domain/failures/invitations_failure.dart';
import 'package:ataulfo/features/invitations/domain/repositories/invitations_repository.dart';
import 'package:ataulfo/features/invitations/presentation/bloc/invitations_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements InvitationsRepository {}

final _i1 = Invitation(
  id: 'i1',
  email: 'a@x.com',
  role: 'WORKER',
  status: 'PENDING',
  expiresAt: DateTime.utc(2026, 6, 1),
  createdAt: DateTime.utc(2026, 5, 25),
);

void main() {
  group('InvitationsBloc', () {
    test('estado inicial = InvitationsInitial', () {
      expect(InvitationsBloc(_MockRepo()).state, const InvitationsInitial());
    });

    blocTest<InvitationsBloc, InvitationsState>(
      'list() ok → [Loading, Loaded(items)]',
      build: () {
        final repo = _MockRepo();
        when(repo.list).thenAnswer((_) async => <Invitation>[_i1]);
        return InvitationsBloc(repo);
      },
      act: (bloc) => bloc.add(const InvitationsLoadRequested()),
      expect: () => <InvitationsState>[
        const InvitationsLoading(),
        InvitationsLoaded(items: <Invitation>[_i1]),
      ],
    );

    blocTest<InvitationsBloc, InvitationsState>(
      'list() ok con [] → [Loading, Loaded(empty)]',
      build: () {
        final repo = _MockRepo();
        when(repo.list).thenAnswer((_) async => const <Invitation>[]);
        return InvitationsBloc(repo);
      },
      act: (bloc) => bloc.add(const InvitationsLoadRequested()),
      expect: () => const <InvitationsState>[
        InvitationsLoading(),
        InvitationsLoaded(items: <Invitation>[]),
      ],
    );

    blocTest<InvitationsBloc, InvitationsState>(
      'forbidden → [Loading, Failed(Forbidden)]',
      build: () {
        final repo = _MockRepo();
        when(repo.list).thenAnswer(
          (_) => Future<List<Invitation>>.error(
            const InvitationsForbiddenFailure(),
          ),
        );
        return InvitationsBloc(repo);
      },
      act: (bloc) => bloc.add(const InvitationsLoadRequested()),
      expect: () => const <InvitationsState>[
        InvitationsLoading(),
        InvitationsFailed(InvitationsForbiddenFailure()),
      ],
    );
  });
}
