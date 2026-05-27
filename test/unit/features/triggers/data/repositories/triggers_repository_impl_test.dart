import 'package:agentic/features/triggers/data/datasources/triggers_datasource.dart';
import 'package:agentic/features/triggers/data/repositories/triggers_repository_impl.dart';
import 'package:agentic/features/triggers/domain/entities/trigger.dart';
import 'package:agentic/features/triggers/domain/failures/triggers_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements TriggersDatasource {}

Trigger _sample({String id = 't1'}) => Trigger(
  id: id,
  templateId: 'tpl1',
  flowId: 'f1',
  triggerType: TriggerType.text,
  matchType: MatchType.exact,
  keyword: 'menu',
  labelId: '',
  labelAction: null,
  scope: TriggerScope.both,
  isActive: true,
  createdAt: DateTime.utc(2026, 5, 1),
  updatedAt: DateTime.utc(2026, 5, 1),
);

void main() {
  setUpAll(() {
    registerFallbackValue(TriggerType.text);
    registerFallbackValue(MatchType.exact);
    registerFallbackValue(LabelAction.add);
    registerFallbackValue(TriggerScope.both);
  });

  late _MockDatasource ds;
  late TriggersRepositoryImpl repo;

  setUp(() {
    ds = _MockDatasource();
    repo = TriggersRepositoryImpl(datasource: ds);
  });

  group('TriggersRepositoryImpl', () {
    test('listTriggers delega 1:1 al datasource', () async {
      when(
        () => ds.listTriggers('tpl1'),
      ).thenAnswer((_) async => <Trigger>[_sample(), _sample(id: 't2')]);
      final out = await repo.listTriggers('tpl1');
      expect(out.map((t) => t.id), <String>['t1', 't2']);
      verify(() => ds.listTriggers('tpl1')).called(1);
    });

    test('relanza TriggersFailure del datasource sin envolver', () async {
      when(
        () => ds.listTriggers('tpl1'),
      ).thenThrow(const TriggersForbiddenFailure());
      await expectLater(
        () => repo.listTriggers('tpl1'),
        throwsA(isA<TriggersForbiddenFailure>()),
      );
    });

    test('createTrigger delega 1:1 al datasource', () async {
      when(
        () => ds.createTrigger(
          templateId: any(named: 'templateId'),
          flowId: any(named: 'flowId'),
          triggerType: any(named: 'triggerType'),
          matchType: any(named: 'matchType'),
          keyword: any(named: 'keyword'),
          labelId: any(named: 'labelId'),
          labelAction: any(named: 'labelAction'),
          scope: any(named: 'scope'),
          isActive: any(named: 'isActive'),
        ),
      ).thenAnswer((_) async => _sample());

      final out = await repo.createTrigger(
        templateId: 'tpl1',
        flowId: 'f1',
        triggerType: TriggerType.text,
        matchType: MatchType.exact,
        keyword: 'menu',
        labelId: '',
        labelAction: null,
        scope: TriggerScope.both,
        isActive: true,
      );
      expect(out.id, 't1');
      verify(
        () => ds.createTrigger(
          templateId: 'tpl1',
          flowId: 'f1',
          triggerType: TriggerType.text,
          matchType: MatchType.exact,
          keyword: 'menu',
          labelId: '',
          labelAction: null,
          scope: TriggerScope.both,
          isActive: true,
        ),
      ).called(1);
    });

    test('updateTrigger delega 1:1 al datasource', () async {
      when(
        () => ds.updateTrigger(
          triggerId: any(named: 'triggerId'),
          triggerType: any(named: 'triggerType'),
          matchType: any(named: 'matchType'),
          keyword: any(named: 'keyword'),
          labelId: any(named: 'labelId'),
          labelAction: any(named: 'labelAction'),
          scope: any(named: 'scope'),
          isActive: any(named: 'isActive'),
        ),
      ).thenAnswer((_) async => _sample());

      final out = await repo.updateTrigger(
        triggerId: 't1',
        triggerType: TriggerType.text,
        matchType: MatchType.contains,
        keyword: 'hola',
        labelId: '',
        labelAction: null,
        scope: TriggerScope.incoming,
        isActive: false,
      );
      expect(out.id, 't1');
      verify(
        () => ds.updateTrigger(
          triggerId: 't1',
          triggerType: TriggerType.text,
          matchType: MatchType.contains,
          keyword: 'hola',
          labelId: '',
          labelAction: null,
          scope: TriggerScope.incoming,
          isActive: false,
        ),
      ).called(1);
    });

    test('deleteTrigger delega 1:1 al datasource', () async {
      when(() => ds.deleteTrigger('t1')).thenAnswer((_) async {});
      await repo.deleteTrigger('t1');
      verify(() => ds.deleteTrigger('t1')).called(1);
    });
  });
}
