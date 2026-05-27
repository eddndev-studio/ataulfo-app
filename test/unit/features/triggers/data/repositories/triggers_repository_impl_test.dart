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
  });
}
