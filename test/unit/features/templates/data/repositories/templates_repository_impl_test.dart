import 'package:agentic/features/templates/data/datasources/templates_datasource.dart';
import 'package:agentic/features/templates/data/repositories/templates_repository_impl.dart';
import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/entities/variable_def.dart';
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

  group('TemplatesRepositoryImpl.list (delegate trivial)', () {
    test('forwarda al datasource y devuelve su lista', () async {
      when(() => ds.list()).thenAnswer((_) async => const <Template>[tpl]);

      final items = await repo.list();

      expect(items, hasLength(1));
      expect(items.first, tpl);
      verify(() => ds.list()).called(1);
    });

    test('propaga TemplatesFailure sin envolver', () async {
      // El datasource real produce un Future fallido (await dentro de try/
      // catch), no un throw síncrono. El stub usa Future.error para que el
      // delegate del repo lo reciba como Future fallido — equivalente a
      // producción.
      when(() => ds.list()).thenAnswer(
        (_) => Future<List<Template>>.error(const TemplatesNetworkFailure()),
      );

      await expectLater(repo.list(), throwsA(isA<TemplatesNetworkFailure>()));
    });
  });

  group('TemplatesRepositoryImpl.create (delegate trivial)', () {
    test('forwarda el name y devuelve el Template del datasource', () async {
      when(() => ds.create('Soporte')).thenAnswer((_) async => tpl);

      final got = await repo.create('Soporte');

      expect(got, tpl);
      verify(() => ds.create('Soporte')).called(1);
    });

    test('propaga TemplatesInvalidNameFailure sin envolver', () async {
      when(() => ds.create('')).thenAnswer(
        (_) => Future<Template>.error(const TemplatesInvalidNameFailure()),
      );

      await expectLater(
        repo.create(''),
        throwsA(isA<TemplatesInvalidNameFailure>()),
      );
    });
  });

  group('TemplatesRepositoryImpl.listVarDefs (delegate trivial)', () {
    const defs = <VariableDef>[
      VariableDef(
        id: 'v1',
        name: 'nombre',
        type: VarType.text,
        defaultValue: 'cliente',
        description: '',
      ),
    ];

    test('forwarda el id y devuelve (version, defs) del datasource', () async {
      when(
        () => ds.listVarDefs('t1'),
      ).thenAnswer((_) async => (version: 5, defs: defs));

      final got = await repo.listVarDefs('t1');

      expect(got.version, 5);
      expect(got.defs, defs);
      verify(() => ds.listVarDefs('t1')).called(1);
    });

    test('propaga TemplatesNotFoundFailure sin envolver', () async {
      when(() => ds.listVarDefs('desconocido')).thenAnswer(
        (_) => Future<({int version, List<VariableDef> defs})>.error(
          const TemplatesNotFoundFailure(),
        ),
      );

      await expectLater(
        repo.listVarDefs('desconocido'),
        throwsA(isA<TemplatesNotFoundFailure>()),
      );
    });
  });

  group('TemplatesRepositoryImpl.update (delegate trivial)', () {
    test(
      'forwarda los named args y devuelve el Template del datasource',
      () async {
        when(
          () => ds.update(id: 't1', name: 'Soporte v2', version: 1, ai: tpl.ai),
        ).thenAnswer((_) async => tpl);

        final got = await repo.update(
          id: 't1',
          name: 'Soporte v2',
          version: 1,
          ai: tpl.ai,
        );

        expect(got, tpl);
        verify(
          () => ds.update(id: 't1', name: 'Soporte v2', version: 1, ai: tpl.ai),
        ).called(1);
      },
    );

    test('propaga TemplatesConflictFailure (CAS) sin envolver', () async {
      when(
        () => ds.update(id: 't1', name: 'x', version: 99, ai: null),
      ).thenAnswer(
        (_) => Future<Template>.error(const TemplatesConflictFailure()),
      );

      await expectLater(
        () => repo.update(id: 't1', name: 'x', version: 99, ai: null),
        throwsA(isA<TemplatesConflictFailure>()),
      );
    });
  });

  group('TemplatesRepositoryImpl.byId (delegate trivial)', () {
    test('forwarda el id y devuelve el Template del datasource', () async {
      when(() => ds.byId('t1')).thenAnswer((_) async => tpl);

      final got = await repo.byId('t1');

      expect(got, tpl);
      verify(() => ds.byId('t1')).called(1);
    });

    test('propaga TemplatesNotFoundFailure sin envolver', () async {
      when(() => ds.byId('desconocido')).thenAnswer(
        (_) => Future<Template>.error(const TemplatesNotFoundFailure()),
      );

      await expectLater(
        repo.byId('desconocido'),
        throwsA(isA<TemplatesNotFoundFailure>()),
      );
    });
  });

  group('TemplatesRepositoryImpl.addVarDef (delegate trivial)', () {
    const newDef = VariableDef(
      id: 'vd_new',
      name: 'saldo',
      type: VarType.text,
      defaultValue: 'x',
      description: 'saldo del cliente',
    );

    test('forwarda named args y devuelve la def del datasource', () async {
      when(
        () => ds.addVarDef(
          templateId: 't1',
          name: 'saldo',
          type: VarType.text,
          defaultValue: 'x',
          description: 'saldo del cliente',
          version: 1,
        ),
      ).thenAnswer((_) async => newDef);

      final got = await repo.addVarDef(
        templateId: 't1',
        name: 'saldo',
        type: VarType.text,
        defaultValue: 'x',
        description: 'saldo del cliente',
        version: 1,
      );

      expect(got, newDef);
      verify(
        () => ds.addVarDef(
          templateId: 't1',
          name: 'saldo',
          type: VarType.text,
          defaultValue: 'x',
          description: 'saldo del cliente',
          version: 1,
        ),
      ).called(1);
    });

    test('propaga TemplatesConflictFailure (409) sin envolver', () async {
      when(
        () => ds.addVarDef(
          templateId: 't1',
          name: 'dup',
          type: VarType.text,
          defaultValue: '',
          description: '',
          version: 1,
        ),
      ).thenAnswer(
        (_) => Future<VariableDef>.error(const TemplatesConflictFailure()),
      );

      await expectLater(
        () => repo.addVarDef(
          templateId: 't1',
          name: 'dup',
          type: VarType.text,
          defaultValue: '',
          description: '',
          version: 1,
        ),
        throwsA(isA<TemplatesConflictFailure>()),
      );
    });
  });

  group('TemplatesRepositoryImpl.updateVarDef (delegate trivial)', () {
    test('forwarda named args incluyendo nullables al datasource', () async {
      when(
        () => ds.updateVarDef(
          varDefId: 'vd_x',
          version: 2,
          name: 'otro',
          defaultValue: null,
          description: '',
        ),
      ).thenAnswer((_) async {});

      await repo.updateVarDef(
        varDefId: 'vd_x',
        version: 2,
        name: 'otro',
        description: '',
      );

      verify(
        () => ds.updateVarDef(
          varDefId: 'vd_x',
          version: 2,
          name: 'otro',
          defaultValue: null,
          description: '',
        ),
      ).called(1);
    });

    test('propaga TemplatesConflictFailure sin envolver', () async {
      when(
        () => ds.updateVarDef(
          varDefId: 'vd_x',
          version: 1,
          name: 'otro',
          defaultValue: null,
          description: null,
        ),
      ).thenAnswer((_) => Future<void>.error(const TemplatesConflictFailure()));

      await expectLater(
        () => repo.updateVarDef(varDefId: 'vd_x', version: 1, name: 'otro'),
        throwsA(isA<TemplatesConflictFailure>()),
      );
    });
  });

  group('TemplatesRepositoryImpl.removeVarDef (delegate trivial)', () {
    test('forwarda named args al datasource', () async {
      when(
        () => ds.removeVarDef(varDefId: 'vd_x', version: 3),
      ).thenAnswer((_) async {});

      await repo.removeVarDef(varDefId: 'vd_x', version: 3);

      verify(() => ds.removeVarDef(varDefId: 'vd_x', version: 3)).called(1);
    });

    test('propaga TemplatesConflictFailure (in-use) sin envolver', () async {
      when(
        () => ds.removeVarDef(varDefId: 'vd_x', version: 1),
      ).thenAnswer((_) => Future<void>.error(const TemplatesConflictFailure()));

      await expectLater(
        () => repo.removeVarDef(varDefId: 'vd_x', version: 1),
        throwsA(isA<TemplatesConflictFailure>()),
      );
    });
  });
}
