import 'package:ataulfo/features/triggers/data/dto/trigger_dto.dart';
import 'package:ataulfo/features/triggers/data/mappers/triggers_mapper.dart';
import 'package:ataulfo/features/triggers/domain/entities/trigger.dart';
import 'package:flutter_test/flutter_test.dart';

TriggerResp _textResp() =>
    const TriggerResp(
      id: 't1',
      templateId: 'tpl1',
      flowId: 'f1',
      type: 'TEXT',
      matchType: 'CONTAINS',
      keyword: 'hola',
      labelId: '',
      labelAction: null,
      scope: 'BOTH',
      isActive: true,
    ).withTimestamps(
      createdAt: DateTime.utc(2026, 5, 1),
      updatedAt: DateTime.utc(2026, 5, 2),
    );

TriggerResp _labelResp() =>
    const TriggerResp(
      id: 't2',
      templateId: 'tpl1',
      flowId: 'f1',
      type: 'LABEL',
      matchType: null,
      keyword: '',
      labelId: 'lbl_vip',
      labelAction: 'ADD',
      scope: 'BOTH',
      isActive: true,
    ).withTimestamps(
      createdAt: DateTime.utc(2026, 5, 1),
      updatedAt: DateTime.utc(2026, 5, 1),
    );

void main() {
  group('TriggersMapper.triggerRespToEntity', () {
    test('TEXT: matchType + keyword poblados; labelAction null', () {
      final t = TriggersMapper.triggerRespToEntity(_textResp());
      expect(t.id, 't1');
      expect(t.triggerType, TriggerType.text);
      expect(t.matchType, MatchType.contains);
      expect(t.keyword, 'hola');
      expect(t.labelAction, isNull);
      expect(t.scope, TriggerScope.both);
    });

    test('LABEL: labelId + labelAction poblados; matchType null', () {
      final t = TriggersMapper.triggerRespToEntity(_labelResp());
      expect(t.triggerType, TriggerType.label);
      expect(t.matchType, isNull);
      expect(t.labelId, 'lbl_vip');
      expect(t.labelAction, LabelAction.add);
    });

    test('type desconocido propaga ArgumentError fail-loud', () {
      const bad = TriggerResp(
        id: 't1',
        templateId: 'tpl1',
        flowId: 'f1',
        type: 'WEBHOOK',
        matchType: null,
        keyword: '',
        labelId: '',
        labelAction: null,
        scope: 'BOTH',
        isActive: true,
      );
      final dto = bad.withTimestamps(
        createdAt: DateTime.utc(2026, 5, 1),
        updatedAt: DateTime.utc(2026, 5, 1),
      );
      expect(
        () => TriggersMapper.triggerRespToEntity(dto),
        throwsArgumentError,
      );
    });
  });

  group('TriggersMapper.listToTriggers', () {
    test('preserva el orden del backend', () {
      final list = ListTriggersResp(
        items: <TriggerResp>[_textResp(), _labelResp()],
      );
      final ts = TriggersMapper.listToTriggers(list);
      expect(ts, hasLength(2));
      expect(ts[0].triggerType, TriggerType.text);
      expect(ts[1].triggerType, TriggerType.label);
    });
  });
}
