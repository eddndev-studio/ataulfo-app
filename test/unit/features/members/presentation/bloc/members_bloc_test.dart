import 'package:ataulfo/features/members/domain/entities/member.dart';
import 'package:ataulfo/features/members/domain/failures/members_failure.dart';
import 'package:ataulfo/features/members/domain/repositories/members_repository.dart';
import 'package:ataulfo/features/members/presentation/bloc/members_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MembersRepository {}

const _m1 = Member(
  id: 'm1',
  userId: 'u1',
  email: 'a@x.com',
  emailVerified: true,
  role: 'OWNER',
);
const _m2 = Member(
  id: 'm2',
  userId: 'u2',
  email: 'b@x.com',
  emailVerified: false,
  role: 'WORKER',
);

void main() {
  group('MembersBloc', () {
    test('estado inicial = MembersInitial', () {
      final bloc = MembersBloc(_MockRepo());
      expect(bloc.state, const MembersInitial());
    });

    group('MembersLoadRequested', () {
      blocTest<MembersBloc, MembersState>(
        'list() ok → [Loading, Loaded(items)]',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer((_) async => const <Member>[_m1, _m2]);
          return MembersBloc(repo);
        },
        act: (bloc) => bloc.add(const MembersLoadRequested()),
        expect: () => const <MembersState>[
          MembersLoading(),
          MembersLoaded(items: <Member>[_m1, _m2]),
        ],
      );

      blocTest<MembersBloc, MembersState>(
        'list() ok con [] → [Loading, Loaded(empty)]',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer((_) async => const <Member>[]);
          return MembersBloc(repo);
        },
        act: (bloc) => bloc.add(const MembersLoadRequested()),
        expect: () => const <MembersState>[
          MembersLoading(),
          MembersLoaded(items: <Member>[]),
        ],
      );

      blocTest<MembersBloc, MembersState>(
        'forbidden → [Loading, Failed(Forbidden)]',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer(
            (_) => Future<List<Member>>.error(const MembersForbiddenFailure()),
          );
          return MembersBloc(repo);
        },
        act: (bloc) => bloc.add(const MembersLoadRequested()),
        expect: () => const <MembersState>[
          MembersLoading(),
          MembersFailed(MembersForbiddenFailure()),
        ],
      );

      blocTest<MembersBloc, MembersState>(
        'server → [Loading, Failed(Server)]',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer(
            (_) => Future<List<Member>>.error(const MembersServerFailure()),
          );
          return MembersBloc(repo);
        },
        act: (bloc) => bloc.add(const MembersLoadRequested()),
        expect: () => const <MembersState>[
          MembersLoading(),
          MembersFailed(MembersServerFailure()),
        ],
      );

      blocTest<MembersBloc, MembersState>(
        'retry desde Failed re-emite Loading visible',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer((_) async => const <Member>[_m1]);
          return MembersBloc(repo);
        },
        seed: () => const MembersFailed(MembersNetworkFailure()),
        act: (bloc) => bloc.add(const MembersLoadRequested()),
        expect: () => const <MembersState>[
          MembersLoading(),
          MembersLoaded(items: <Member>[_m1]),
        ],
      );
    });
  });
}
