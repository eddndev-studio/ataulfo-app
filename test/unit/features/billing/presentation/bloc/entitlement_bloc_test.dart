import 'package:ataulfo/features/billing/domain/entities/entitlement.dart';
import 'package:ataulfo/features/billing/domain/failures/billing_failure.dart';
import 'package:ataulfo/features/billing/domain/repositories/billing_repository.dart';
import 'package:ataulfo/features/billing/presentation/bloc/entitlement_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements BillingRepository {}

const _entitlement = Entitlement(
  planCode: 'trial',
  status: 'trialing',
  usedConversations: 12,
  conversationCap: 50,
  withinQuota: true,
  quotaExceeded: false,
  storageUsedMb: 100,
  storageQuotaMb: 512,
  eligibleProviders: <String>{'MINIMAX', 'NEMOTRON'},
  features: <String>['media_gallery'],
);

void main() {
  group('EntitlementBloc', () {
    test('estado inicial = EntitlementInitial', () {
      final bloc = EntitlementBloc(_MockRepo());
      expect(bloc.state, const EntitlementInitial());
    });

    group('EntitlementLoadRequested', () {
      blocTest<EntitlementBloc, EntitlementState>(
        'fetch() ok → [Loading, Loaded(entitlement)]',
        build: () {
          final repo = _MockRepo();
          when(repo.fetch).thenAnswer((_) async => _entitlement);
          return EntitlementBloc(repo);
        },
        act: (bloc) => bloc.add(const EntitlementLoadRequested()),
        expect: () => const <EntitlementState>[
          EntitlementLoading(),
          EntitlementLoaded(entitlement: _entitlement),
        ],
      );

      blocTest<EntitlementBloc, EntitlementState>(
        'org sin resolver (409) → [Loading, Failed(OrgUnresolved)]',
        build: () {
          final repo = _MockRepo();
          when(repo.fetch).thenAnswer(
            (_) =>
                Future<Entitlement>.error(const BillingOrgUnresolvedFailure()),
          );
          return EntitlementBloc(repo);
        },
        act: (bloc) => bloc.add(const EntitlementLoadRequested()),
        expect: () => const <EntitlementState>[
          EntitlementLoading(),
          EntitlementFailed(BillingOrgUnresolvedFailure()),
        ],
      );

      blocTest<EntitlementBloc, EntitlementState>(
        'red caída → [Loading, Failed(Network)]',
        build: () {
          final repo = _MockRepo();
          when(repo.fetch).thenAnswer(
            (_) => Future<Entitlement>.error(const BillingNetworkFailure()),
          );
          return EntitlementBloc(repo);
        },
        act: (bloc) => bloc.add(const EntitlementLoadRequested()),
        expect: () => const <EntitlementState>[
          EntitlementLoading(),
          EntitlementFailed(BillingNetworkFailure()),
        ],
      );
    });
  });
}
