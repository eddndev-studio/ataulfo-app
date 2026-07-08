import 'package:ataulfo/features/billing/data/dto/entitlement_dto.dart';
import 'package:ataulfo/features/billing/data/mappers/entitlement_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EntitlementMapper.dtoToEntity', () {
    test('proyecta todos los campos del wire a la entidad', () {
      const dto = EntitlementDto(
        planCode: 'starter',
        status: 'active',
        trialExpired: true,
        usedConversations: 42,
        conversationCap: 100,
        withinQuota: true,
        quotaExceeded: false,
        storageUsedMb: 900,
        storageQuotaMb: 2048,
        eligibleProviders: <String>['MINIMAX', 'NEMOTRON', 'DEEPSEEK'],
        features: <String>['media_gallery'],
      );

      final e = EntitlementMapper.dtoToEntity(dto);

      expect(e.planCode, 'starter');
      expect(e.status, 'active');
      expect(e.trialExpired, isTrue);
      expect(e.usedConversations, 42);
      expect(e.conversationCap, 100);
      expect(e.withinQuota, isTrue);
      expect(e.quotaExceeded, isFalse);
      expect(e.storageUsedMb, 900);
      expect(e.storageQuotaMb, 2048);
      expect(e.features, <String>['media_gallery']);
    });

    test('eligible_providers: la lista del wire llega como SET de crudos', () {
      const dto = EntitlementDto(
        planCode: 'trial',
        status: 'trialing',
        trialExpired: false,
        usedConversations: 0,
        conversationCap: 50,
        withinQuota: true,
        quotaExceeded: false,
        storageUsedMb: 0,
        storageQuotaMb: 512,
        // Un backend defectuoso podría repetir; el set colapsa duplicados.
        eligibleProviders: <String>['MINIMAX', 'NEMOTRON', 'MINIMAX'],
        features: <String>[],
      );

      final e = EntitlementMapper.dtoToEntity(dto);

      expect(e.eligibleProviders, <String>{'MINIMAX', 'NEMOTRON'});
    });
  });
}
