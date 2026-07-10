import 'package:ataulfo/features/billing/data/dto/entitlement_dto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _body({
  Object? planCode = 'trial',
  Object? trialExpired = false,
  Object? eligibleProviders = const <dynamic>['MINIMAX', 'NEMOTRON'],
  Object? features = const <dynamic>['media_gallery'],
}) => <String, dynamic>{
  'plan_code': planCode,
  'status': 'trialing',
  'trial_expired': trialExpired,
  'credits_used': 12,
  'credit_cap': 800,
  'within_quota': true,
  'quota_exceeded': false,
  'storage_used_mb': 100,
  'storage_quota_mb': 512,
  'eligible_providers': eligibleProviders,
  'features': features,
};

void main() {
  group('EntitlementDto.fromJson', () {
    test('parsea el wire completo (claves snake_case del backend)', () {
      final dto = EntitlementDto.fromJson(_body());

      expect(dto.planCode, 'trial');
      expect(dto.status, 'trialing');
      expect(dto.trialExpired, isFalse);
      expect(dto.creditsUsed, 12);
      expect(dto.creditCap, 800);
      expect(dto.withinQuota, isTrue);
      expect(dto.quotaExceeded, isFalse);
      expect(dto.storageUsedMb, 100);
      expect(dto.storageQuotaMb, 512);
      expect(dto.eligibleProviders, <String>['MINIMAX', 'NEMOTRON']);
      expect(dto.features, <String>['media_gallery']);
    });

    test('listas vacías son válidas (el backend encoda [] nunca null)', () {
      final dto = EntitlementDto.fromJson(
        _body(
          eligibleProviders: const <dynamic>[],
          features: const <dynamic>[],
        ),
      );

      expect(dto.eligibleProviders, isEmpty);
      expect(dto.features, isEmpty);
    });

    test('trial_expired=true del wire se parsea', () {
      final dto = EntitlementDto.fromJson(_body(trialExpired: true));
      expect(dto.trialExpired, isTrue);
    });

    test('trial_expired AUSENTE ⇒ false (backend viejo no rompe)', () {
      // Campo aditivo: un backend anterior al enforcement de trial no lo
      // encoda todavía; degradar a false conserva el parse estricto del resto.
      final body = _body()..remove('trial_expired');
      final dto = EntitlementDto.fromJson(body);
      expect(dto.trialExpired, isFalse);
    });

    test('trial_expired presente con tipo inválido ⇒ FormatException', () {
      expect(
        () => EntitlementDto.fromJson(_body(trialExpired: 'yes')),
        throwsFormatException,
      );
    });

    test('sin claves de créditos ⇒ cae al espejo legacy de conversaciones', () {
      // Un backend anterior a la métrica de créditos solo encoda
      // used_conversations/conversation_cap; el DTO los toma como consumo.
      final body = _body()
        ..remove('credits_used')
        ..remove('credit_cap')
        ..addAll(<String, dynamic>{
          'used_conversations': 7,
          'conversation_cap': 50,
        });
      final dto = EntitlementDto.fromJson(body);
      expect(dto.creditsUsed, 7);
      expect(dto.creditCap, 50);
    });

    test('las claves canónicas de créditos GANAN al espejo legacy', () {
      // El backend nuevo emite ambos pares con los mismos valores; si
      // difirieran, la verdad es la canónica.
      final body = _body()
        ..addAll(<String, dynamic>{
          'used_conversations': 999,
          'conversation_cap': 999,
        });
      final dto = EntitlementDto.fromJson(body);
      expect(dto.creditsUsed, 12);
      expect(dto.creditCap, 800);
    });

    test('sin créditos NI espejo legacy ⇒ FormatException', () {
      final body = _body()
        ..remove('credits_used')
        ..remove('credit_cap');
      expect(() => EntitlementDto.fromJson(body), throwsFormatException);
    });

    test('credits_used con tipo inválido ⇒ FormatException', () {
      final body = _body()..['credits_used'] = 'doce';
      expect(() => EntitlementDto.fromJson(body), throwsFormatException);
    });

    test('clave obligatoria ausente ⇒ FormatException', () {
      final body = _body()..remove('plan_code');
      expect(() => EntitlementDto.fromJson(body), throwsFormatException);
    });

    test('tipo inválido en escalar ⇒ FormatException', () {
      expect(
        () => EntitlementDto.fromJson(_body(planCode: 7)),
        throwsFormatException,
      );
    });

    test('eligible_providers no-lista ⇒ FormatException', () {
      expect(
        () => EntitlementDto.fromJson(_body(eligibleProviders: 'MINIMAX')),
        throwsFormatException,
      );
    });

    test('elemento no-string dentro de la lista ⇒ FormatException', () {
      expect(
        () => EntitlementDto.fromJson(
          _body(eligibleProviders: const <dynamic>['MINIMAX', 3]),
        ),
        throwsFormatException,
      );
    });
  });
}
