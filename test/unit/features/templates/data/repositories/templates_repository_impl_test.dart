import 'package:agentic/features/templates/data/datasources/templates_datasource.dart';
import 'package:agentic/features/templates/data/repositories/templates_repository_impl.dart';
import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements TemplatesDatasource {}

void main() {
  late _MockDs ds;
  late TemplatesRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    repo = TemplatesRepositoryImpl(datasource: ds);
  });

  group('TemplatesRepositoryImpl.list (delegate trivial)', () {
    test('forwarda al datasource y devuelve su lista', () async {
      const tpl = Template(
        id: 't1',
        orgId: 'o1',
        name: 'Soporte',
        version: 1,
        ai: AIConfig(
          enabled: false,
          provider: AIProvider.gemini,
          model: 'gemini-3.1-pro-preview',
          temperature: 0.7,
          thinkingLevel: ThinkingLevel.low,
          systemPrompt: '',
          contextMessages: 20,
        ),
      );
      when(() => ds.list()).thenAnswer((_) async => const <Template>[tpl]);

      final items = await repo.list();

      expect(items, hasLength(1));
      expect(items.first, tpl);
      verify(() => ds.list()).called(1);
    });

    test('propaga TemplatesFailure sin envolver', () async {
      when(() => ds.list()).thenThrow(const TemplatesNetworkFailure());

      await expectLater(repo.list(), throwsA(isA<TemplatesNetworkFailure>()));
    });
  });
}
