import 'package:ataulfo/features/billing/data/dto/entitlement_dto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _body({
  Object? planCode = 'trial',
  Object? eligibleProviders = const <dynamic>['MINIMAX', 'NEMOTRON'],
  Object? features = const <dynamic>['media_gallery'],
}) => <String, dynamic>{
  'plan_code': planCode,
  'status': 'trialing',
  'used_conversations': 12,
  'conversation_cap': 50,
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
      expect(dto.usedConversations, 12);
      expect(dto.conversationCap, 50);
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
