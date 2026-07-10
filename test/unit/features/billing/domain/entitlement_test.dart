import 'package:ataulfo/features/billing/domain/entities/entitlement.dart';
import 'package:flutter_test/flutter_test.dart';

Entitlement _base({
  Set<String> eligibleProviders = const <String>{'MINIMAX', 'NEMOTRON'},
  List<String> features = const <String>['media_gallery'],
  int creditsUsed = 12,
  bool trialExpired = false,
}) => Entitlement(
  planCode: 'trial',
  status: 'trialing',
  trialExpired: trialExpired,
  creditsUsed: creditsUsed,
  creditCap: 800,
  withinQuota: true,
  quotaExceeded: false,
  storageUsedMb: 100,
  storageQuotaMb: 512,
  eligibleProviders: eligibleProviders,
  features: features,
);

void main() {
  group('Entitlement', () {
    test('value equality: mismos campos ⇒ iguales (y mismo hashCode)', () {
      expect(_base(), equals(_base()));
      expect(_base().hashCode, equals(_base().hashCode));
    });

    test('eligibleProviders compara por CONTENIDO del set, no por orden', () {
      // El wire trae una lista; el dominio la guarda como set. Dos fotos con
      // los mismos proveedores en distinto orden de llegada son la misma
      // foto — un == por identidad haría re-renders espurios en el bloc.
      final a = _base(eligibleProviders: {'MINIMAX', 'NEMOTRON'});
      final b = _base(eligibleProviders: {'NEMOTRON', 'MINIMAX'});
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('difiere por eligibleProviders', () {
      expect(
        _base(eligibleProviders: {'MINIMAX'}),
        isNot(equals(_base(eligibleProviders: {'MINIMAX', 'NEMOTRON'}))),
      );
    });

    test('difiere por créditos consumidos', () {
      expect(_base(creditsUsed: 12), isNot(equals(_base(creditsUsed: 13))));
    });

    test('difiere por trialExpired', () {
      expect(
        _base(trialExpired: true),
        isNot(equals(_base(trialExpired: false))),
      );
    });

    test('difiere por features', () {
      expect(
        _base(features: const <String>[]),
        isNot(equals(_base(features: const <String>['media_gallery']))),
      );
    });
  });
}
