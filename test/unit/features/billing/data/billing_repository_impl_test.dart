import 'package:ataulfo/features/billing/data/datasources/billing_datasource.dart';
import 'package:ataulfo/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:ataulfo/features/billing/domain/entities/entitlement.dart';
import 'package:ataulfo/features/billing/domain/failures/billing_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements BillingDatasource {}

const _entitlement = Entitlement(
  planCode: 'trial',
  status: 'trialing',
  trialExpired: false,
  creditsUsed: 12,
  creditCap: 800,
  withinQuota: true,
  quotaExceeded: false,
  storageUsedMb: 100,
  storageQuotaMb: 512,
  eligibleProviders: <String>{'MINIMAX', 'NEMOTRON'},
  features: <String>['media_gallery'],
);

void main() {
  late _MockDs ds;
  late BillingRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    repo = BillingRepositoryImpl(datasource: ds);
  });

  group('BillingRepositoryImpl.fetch', () {
    test('delega al datasource y devuelve el entitlement', () async {
      when(() => ds.fetch()).thenAnswer((_) async => _entitlement);

      final got = await repo.fetch();

      expect(got, _entitlement);
      verify(() => ds.fetch()).called(1);
    });

    test('propaga la failure del datasource sin envolverla', () async {
      when(() => ds.fetch()).thenThrow(const BillingNetworkFailure());

      // Closure: mocktail.thenThrow lanza sync al invocarse; expectLater
      // necesita una función para atrapar sync-throws igual que async.
      await expectLater(
        () => repo.fetch(),
        throwsA(isA<BillingNetworkFailure>()),
      );
    });
  });
}
