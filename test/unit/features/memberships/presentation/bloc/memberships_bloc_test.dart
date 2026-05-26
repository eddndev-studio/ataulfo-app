import 'package:agentic/features/memberships/domain/entities/membership.dart';
import 'package:agentic/features/memberships/domain/failures/memberships_failure.dart';
import 'package:agentic/features/memberships/domain/repositories/memberships_repository.dart';
import 'package:agentic/features/memberships/presentation/bloc/memberships_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MembershipsRepository {}

const _m1 = Membership(orgId: 'o1', orgName: 'Acme', role: 'OWNER');
const _m2 = Membership(orgId: 'o2', orgName: 'Bravo', role: 'ADMIN');

void main() {
  group('MembershipsBloc', () {
    test('estado inicial = MembershipsInitial', () {
      final bloc = MembershipsBloc(_MockRepo());
      expect(bloc.state, const MembershipsInitial());
    });

    group('MembershipsLoadRequested', () {
      blocTest<MembershipsBloc, MembershipsState>(
        'list() ok → [Loading, Loaded(items)]',
        build: () {
          final repo = _MockRepo();
          when(
            repo.list,
          ).thenAnswer((_) async => const <Membership>[_m1, _m2]);
          return MembershipsBloc(repo);
        },
        act: (bloc) => bloc.add(const MembershipsLoadRequested()),
        expect: () => const <MembershipsState>[
          MembershipsLoading(),
          MembershipsLoaded(items: <Membership>[_m1, _m2]),
        ],
      );

      blocTest<MembershipsBloc, MembershipsState>(
        'list() ok con [] → [Loading, Loaded(empty)]',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer((_) async => const <Membership>[]);
          return MembershipsBloc(repo);
        },
        act: (bloc) => bloc.add(const MembershipsLoadRequested()),
        expect: () => const <MembershipsState>[
          MembershipsLoading(),
          MembershipsLoaded(items: <Membership>[]),
        ],
      );

      blocTest<MembershipsBloc, MembershipsState>(
        'forbidden → [Loading, Failed(Forbidden)]',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer(
            (_) => Future<List<Membership>>.error(
              const MembershipsForbiddenFailure(),
            ),
          );
          return MembershipsBloc(repo);
        },
        act: (bloc) => bloc.add(const MembershipsLoadRequested()),
        expect: () => const <MembershipsState>[
          MembershipsLoading(),
          MembershipsFailed(MembershipsForbiddenFailure()),
        ],
      );

      blocTest<MembershipsBloc, MembershipsState>(
        'network → [Loading, Failed(Network)]',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer(
            (_) => Future<List<Membership>>.error(
              const MembershipsNetworkFailure(),
            ),
          );
          return MembershipsBloc(repo);
        },
        act: (bloc) => bloc.add(const MembershipsLoadRequested()),
        expect: () => const <MembershipsState>[
          MembershipsLoading(),
          MembershipsFailed(MembershipsNetworkFailure()),
        ],
      );

      blocTest<MembershipsBloc, MembershipsState>(
        'retry desde Failed re-emite Loading visible',
        build: () {
          final repo = _MockRepo();
          when(
            repo.list,
          ).thenAnswer((_) async => const <Membership>[_m1]);
          return MembershipsBloc(repo);
        },
        // El primer load lo emite el caller; este test simula el segundo
        // (retry tras Failed) reusando LoadRequested.
        seed: () => const MembershipsFailed(MembershipsNetworkFailure()),
        act: (bloc) => bloc.add(const MembershipsLoadRequested()),
        expect: () => const <MembershipsState>[
          MembershipsLoading(),
          MembershipsLoaded(items: <Membership>[_m1]),
        ],
      );
    });
  });
}
