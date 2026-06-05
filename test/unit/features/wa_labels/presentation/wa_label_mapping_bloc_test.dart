import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/failures/labels_failure.dart';
import 'package:ataulfo/features/labels/domain/repositories/labels_repository.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_mapping.dart';
import 'package:ataulfo/features/wa_labels/domain/failures/wa_labels_failure.dart';
import 'package:ataulfo/features/wa_labels/domain/repositories/wa_labels_repository.dart';
import 'package:ataulfo/features/wa_labels/presentation/bloc/wa_label_mapping_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWaRepo extends Mock implements WaLabelsRepository {}

class _MockLabelsRepo extends Mock implements LabelsRepository {}

WaLabel _wa({String id = '1000', bool deleted = false}) =>
    WaLabel(waLabelId: id, name: 'WA$id', color: 3, deleted: deleted);

Label _il({String id = 'uuid-vip', String name = 'VIP'}) =>
    Label(id: id, name: name, color: '#34B7F1', description: '');

void main() {
  late _MockWaRepo wa;
  late _MockLabelsRepo labels;

  setUp(() {
    wa = _MockWaRepo();
    labels = _MockLabelsRepo();
  });

  WaLabelMappingBloc build() =>
      WaLabelMappingBloc(waRepo: wa, labelsRepo: labels, botId: 'b1');

  void stubLoad({
    List<WaLabel>? catalog,
    List<WaLabelMapping>? mappings,
    List<Label>? internal,
  }) {
    when(() => wa.listCatalog('b1')).thenAnswer(
      (_) async => catalog ?? <WaLabel>[_wa(), _wa(id: '1001', deleted: true)],
    );
    when(() => wa.listMappings('b1')).thenAnswer(
      (_) async =>
          mappings ??
          <WaLabelMapping>[
            const WaLabelMapping(waLabelId: '1000', labelId: 'uuid-vip'),
          ],
    );
    when(
      () => labels.listLabels(),
    ).thenAnswer((_) async => internal ?? <Label>[_il()]);
  }

  group('carga', () {
    blocTest<WaLabelMappingBloc, WaMappingState>(
      'une catálogo activo + mapeos + labels internos',
      build: () {
        stubLoad();
        return build();
      },
      act: (b) => b.add(const WaMappingLoadRequested()),
      verify: (b) {
        final s = b.state as WaMappingLoaded;
        // Solo etiquetas WA activas (filtra tombstones).
        expect(s.data.waLabels.map((l) => l.waLabelId), <String>['1000']);
        expect(s.data.mappings['1000'], 'uuid-vip');
        expect(s.data.internalLabels.single.name, 'VIP');
        // Resuelve el label mapeado.
        expect(s.data.mappedLabel('1000')?.name, 'VIP');
        expect(s.data.mappedLabel('1001'), isNull);
      },
    );

    blocTest<WaLabelMappingBloc, WaMappingState>(
      'fallo del catálogo (403) → Failed forbidden',
      build: () {
        when(
          () => wa.listCatalog('b1'),
        ).thenThrow(const WaLabelsForbiddenFailure());
        when(
          () => wa.listMappings('b1'),
        ).thenAnswer((_) async => const <WaLabelMapping>[]);
        when(() => labels.listLabels()).thenAnswer((_) async => <Label>[_il()]);
        return build();
      },
      act: (b) => b.add(const WaMappingLoadRequested()),
      expect: () => <WaMappingState>[
        const WaMappingFailed(WaMappingError.forbidden),
      ],
    );

    blocTest<WaLabelMappingBloc, WaMappingState>(
      'fallo de labels internos (network) → Failed network',
      build: () {
        when(
          () => wa.listCatalog('b1'),
        ).thenAnswer((_) async => <WaLabel>[_wa()]);
        when(
          () => wa.listMappings('b1'),
        ).thenAnswer((_) async => const <WaLabelMapping>[]);
        when(() => labels.listLabels()).thenThrow(const LabelsNetworkFailure());
        return build();
      },
      act: (b) => b.add(const WaMappingLoadRequested()),
      expect: () => <WaMappingState>[
        const WaMappingFailed(WaMappingError.network),
      ],
    );
  });

  group('set/clear', () {
    blocTest<WaLabelMappingBloc, WaMappingState>(
      'set → Mutating luego Loaded con el mapeo optimista',
      build: () {
        stubLoad(mappings: const <WaLabelMapping>[]);
        when(
          () => wa.setMapping(
            botId: 'b1',
            waLabelId: '1000',
            labelId: 'uuid-vip',
          ),
        ).thenAnswer(
          (_) async =>
              const WaLabelMapping(waLabelId: '1000', labelId: 'uuid-vip'),
        );
        return build();
      },
      act: (b) async {
        b.add(const WaMappingLoadRequested());
        await b.stream.firstWhere((s) => s is WaMappingLoaded);
        b.add(
          const WaMappingSetRequested(waLabelId: '1000', labelId: 'uuid-vip'),
        );
      },
      skip: 1, // salta el Loaded inicial
      expect: () => <Matcher>[
        isA<WaMappingMutating>(),
        isA<WaMappingLoaded>().having(
          (s) => s.data.mappings['1000'],
          'mapeo',
          'uuid-vip',
        ),
      ],
    );

    blocTest<WaLabelMappingBloc, WaMappingState>(
      'set con 422 → MutationFailed (label inexistente en la org)',
      build: () {
        stubLoad(mappings: const <WaLabelMapping>[]);
        when(
          () => wa.setMapping(
            botId: any(named: 'botId'),
            waLabelId: any(named: 'waLabelId'),
            labelId: any(named: 'labelId'),
          ),
        ).thenThrow(const WaLabelsInvalidFailure());
        return build();
      },
      act: (b) async {
        b.add(const WaMappingLoadRequested());
        await b.stream.firstWhere((s) => s is WaMappingLoaded);
        b.add(const WaMappingSetRequested(waLabelId: '1000', labelId: 'ghost'));
      },
      skip: 1,
      expect: () => <Matcher>[
        isA<WaMappingMutating>(),
        isA<WaMappingMutationFailed>().having(
          (s) => s.failure,
          'failure',
          isA<WaLabelsInvalidFailure>(),
        ),
      ],
    );

    blocTest<WaLabelMappingBloc, WaMappingState>(
      'clear → Loaded sin el mapeo',
      build: () {
        stubLoad();
        when(
          () => wa.deleteMapping(botId: 'b1', waLabelId: '1000'),
        ).thenAnswer((_) async {});
        return build();
      },
      act: (b) async {
        b.add(const WaMappingLoadRequested());
        await b.stream.firstWhere((s) => s is WaMappingLoaded);
        b.add(const WaMappingClearRequested(waLabelId: '1000'));
      },
      skip: 1,
      expect: () => <Matcher>[
        isA<WaMappingMutating>(),
        isA<WaMappingLoaded>().having(
          (s) => s.data.mappings.containsKey('1000'),
          'sin mapeo',
          isFalse,
        ),
      ],
    );
  });

  group('selectableLabelsFor (exclusividad 1:1 reflejada en UI)', () {
    WaMappingData data(Map<String, String> mappings) => WaMappingData(
      waLabels: <WaLabel>[
        _wa(),
        _wa(id: '1001'),
        _wa(id: '1002'),
        _wa(id: '1003'),
      ],
      mappings: mappings,
      internalLabels: <Label>[
        _il(id: 'uuid-vip', name: 'VIP'),
        _il(id: 'uuid-spam', name: 'Spam'),
        _il(id: 'uuid-urgent', name: 'Urgente'),
      ],
    );

    test('sin mapeos devuelve todos los labels internos', () {
      expect(
        data(
          const <String, String>{},
        ).selectableLabelsFor('1000').map((l) => l.id).toList(),
        <String>['uuid-vip', 'uuid-spam', 'uuid-urgent'],
      );
    });

    test('oculta el label ya mapeado a OTRA etiqueta WhatsApp', () {
      // uuid-spam vive en 1001 ⇒ no seleccionable al editar 1000.
      expect(
        data(const <String, String>{
          '1001': 'uuid-spam',
        }).selectableLabelsFor('1000').map((l) => l.id).toList(),
        <String>['uuid-vip', 'uuid-urgent'],
      );
    });

    test('conserva el label vinculado a ESTA etiqueta (la que se edita)', () {
      // uuid-vip mapeado a la propia 1000 ⇒ sigue seleccionable (marcado +
      // removible); uuid-spam mapeado a 1001 ⇒ oculto.
      expect(
        data(const <String, String>{
          '1000': 'uuid-vip',
          '1001': 'uuid-spam',
        }).selectableLabelsFor('1000').map((l) => l.id).toList(),
        <String>['uuid-vip', 'uuid-urgent'],
      );
    });

    test('todos tomados por otras etiquetas ⇒ lista vacía', () {
      expect(
        data(const <String, String>{
          '1001': 'uuid-vip',
          '1002': 'uuid-spam',
          '1003': 'uuid-urgent',
        }).selectableLabelsFor('1000'),
        isEmpty,
      );
    });

    test('conserva el propio label aunque otra etiqueta apunte al mismo', () {
      // Estado que el backend hace imposible (UNIQUE bot_id,label_id), pero la
      // función nunca debe esconder el vínculo de la fila que se edita: si lo
      // hiciera, el operador perdería de vista su propia asignación.
      expect(
        data(const <String, String>{
          '1000': 'uuid-vip',
          '1001': 'uuid-vip',
        }).selectableLabelsFor('1000').map((l) => l.id),
        contains('uuid-vip'),
      );
    });

    test('mapeo huérfano (su etiqueta WhatsApp fue borrada) NO bloquea su label', () {
      // La etiqueta WhatsApp 1001 fue borrada (ausente de waLabels) pero su fila
      // de mapeo a uuid-spam sobrevivió huérfana. No debe bloquear uuid-spam al
      // editar otra etiqueta — si no, esa org-label queda inseleccionable para
      // siempre (defensa cliente; el backend ya limpia el mapeo en label.wa.removed).
      final d = WaMappingData(
        waLabels: <WaLabel>[
          _wa(),
          _wa(id: '1002'),
        ],
        mappings: const <String, String>{'1001': 'uuid-spam'},
        internalLabels: <Label>[
          _il(id: 'uuid-vip', name: 'VIP'),
          _il(id: 'uuid-spam', name: 'Spam'),
        ],
      );
      expect(d.selectableLabelsFor('1000').map((l) => l.id).toList(), <String>[
        'uuid-vip',
        'uuid-spam',
      ]);
    });
  });
}
