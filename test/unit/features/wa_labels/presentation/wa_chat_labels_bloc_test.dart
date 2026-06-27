import 'dart:async';

import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_chat_assoc.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_live_event.dart';
import 'package:ataulfo/features/wa_labels/domain/failures/wa_labels_failure.dart';
import 'package:ataulfo/features/wa_labels/domain/repositories/wa_labels_repository.dart';
import 'package:ataulfo/features/wa_labels/presentation/bloc/wa_chat_labels_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements WaLabelsRepository {}

WaLabel _wa({String id = '1000', bool deleted = false}) =>
    WaLabel(waLabelId: id, name: 'WA$id', color: 3, deleted: deleted);

void main() {
  setUpAll(() => registerFallbackValue(ConversationKind.dm));

  late _MockRepo repo;
  late StreamController<WaLabelLiveEvent> live;

  setUp(() {
    repo = _MockRepo();
    live = StreamController<WaLabelLiveEvent>.broadcast();
    when(
      () => repo.liveEvents(any()),
    ).thenAnswer((_) => const Stream<WaLabelLiveEvent>.empty());
  });

  tearDown(() => live.close());

  WaChatLabelsBloc build() => WaChatLabelsBloc(
    repo: repo,
    botId: 'b1',
    chatLid: 'c1',
    kind: ConversationKind.dm,
  );

  void stubLoad({List<WaLabel>? catalog, List<WaChatAssoc>? assocs}) {
    when(
      () => repo.listCatalog('b1'),
    ).thenAnswer((_) async => catalog ?? <WaLabel>[_wa(), _wa(id: '1001')]);
    when(() => repo.listChatAssocs('b1')).thenAnswer(
      (_) async =>
          assocs ??
          <WaChatAssoc>[
            // c1 tiene 1000; el 1001 está como labeled:false (desasociado); otro
            // chat (c2) no cuenta.
            const WaChatAssoc(chatLid: 'c1', waLabelId: '1000', labeled: true),
            const WaChatAssoc(chatLid: 'c1', waLabelId: '1001', labeled: false),
            const WaChatAssoc(chatLid: 'c2', waLabelId: '1001', labeled: true),
          ],
    );
  }

  group('carga', () {
    blocTest<WaChatLabelsBloc, WaChatLabelsState>(
      'une catálogo activo + asociaciones del chat (solo labeled de este chat)',
      build: () {
        stubLoad();
        return build();
      },
      act: (b) => b.add(const WaChatLabelsLoadRequested()),
      verify: (b) {
        final s = b.state as WaChatLabelsLoaded;
        expect(s.catalog.map((l) => l.waLabelId), <String>['1000', '1001']);
        expect(s.associated, <String>{'1000'}); // solo el labeled:true de c1
      },
    );

    blocTest<WaChatLabelsBloc, WaChatLabelsState>(
      'fallo de carga → Failed',
      build: () {
        when(
          () => repo.listCatalog('b1'),
        ).thenAnswer((_) async => <WaLabel>[_wa()]);
        when(
          () => repo.listChatAssocs('b1'),
        ).thenThrow(const WaLabelsForbiddenFailure());
        return build();
      },
      act: (b) => b.add(const WaChatLabelsLoadRequested()),
      expect: () => <Matcher>[isA<WaChatLabelsFailed>()],
    );
  });

  group('toggle', () {
    blocTest<WaChatLabelsBloc, WaChatLabelsState>(
      'asociar → labelChat(labeled:true) y añade al set',
      build: () {
        stubLoad();
        when(
          () => repo.labelChat(
            botId: 'b1',
            waLabelId: '1001',
            chatLid: 'c1',
            kind: ConversationKind.dm,
            labeled: true,
          ),
        ).thenAnswer((_) async {});
        return build();
      },
      act: (b) async {
        b.add(const WaChatLabelsLoadRequested());
        await b.stream.firstWhere((s) => s is WaChatLabelsLoaded);
        b.add(
          const WaChatLabelsToggleRequested(waLabelId: '1001', associate: true),
        );
      },
      skip: 1,
      expect: () => <Matcher>[
        isA<WaChatLabelsMutating>(),
        isA<WaChatLabelsLoaded>().having(
          (s) => s.associated.contains('1001'),
          'asociado 1001',
          isTrue,
        ),
      ],
    );

    blocTest<WaChatLabelsBloc, WaChatLabelsState>(
      'desasociar con 409 → MutationFailed (bot no conectado)',
      build: () {
        stubLoad();
        when(
          () => repo.labelChat(
            botId: any(named: 'botId'),
            waLabelId: any(named: 'waLabelId'),
            chatLid: any(named: 'chatLid'),
            kind: any(named: 'kind'),
            labeled: any(named: 'labeled'),
          ),
        ).thenThrow(const WaLabelsNotConnectedFailure());
        return build();
      },
      act: (b) async {
        b.add(const WaChatLabelsLoadRequested());
        await b.stream.firstWhere((s) => s is WaChatLabelsLoaded);
        b.add(
          const WaChatLabelsToggleRequested(
            waLabelId: '1000',
            associate: false,
          ),
        );
      },
      skip: 1,
      expect: () => <Matcher>[
        isA<WaChatLabelsMutating>(),
        isA<WaChatLabelsMutationFailed>().having(
          (s) => s.failure,
          'failure',
          isA<WaLabelsNotConnectedFailure>(),
        ),
      ],
    );

    blocTest<WaChatLabelsBloc, WaChatLabelsState>(
      'el toggle es OPTIMISTA: Mutating ya lleva el cambio aplicado',
      build: () {
        stubLoad();
        when(
          () => repo.labelChat(
            botId: any(named: 'botId'),
            waLabelId: any(named: 'waLabelId'),
            chatLid: any(named: 'chatLid'),
            kind: any(named: 'kind'),
            labeled: any(named: 'labeled'),
          ),
        ).thenAnswer((_) async {});
        return build();
      },
      act: (b) async {
        b.add(const WaChatLabelsLoadRequested());
        await b.stream.firstWhere((s) => s is WaChatLabelsLoaded);
        b.add(
          const WaChatLabelsToggleRequested(waLabelId: '1001', associate: true),
        );
      },
      skip: 1,
      expect: () => <Matcher>[
        // El checkbox cambia YA (sin esperar 1-3s al push a WhatsApp); el
        // spinner del título confirma la sincronización en curso.
        isA<WaChatLabelsMutating>().having(
          (s) => s.associated.contains('1001'),
          'optimista',
          isTrue,
        ),
        isA<WaChatLabelsLoaded>().having(
          (s) => s.associated.contains('1001'),
          'confirmado',
          isTrue,
        ),
      ],
    );

    blocTest<WaChatLabelsBloc, WaChatLabelsState>(
      'fallo del push → rollback al set PRE-toggle',
      build: () {
        stubLoad();
        when(
          () => repo.labelChat(
            botId: any(named: 'botId'),
            waLabelId: any(named: 'waLabelId'),
            chatLid: any(named: 'chatLid'),
            kind: any(named: 'kind'),
            labeled: any(named: 'labeled'),
          ),
        ).thenThrow(const WaLabelsNotConnectedFailure());
        return build();
      },
      act: (b) async {
        b.add(const WaChatLabelsLoadRequested());
        await b.stream.firstWhere((s) => s is WaChatLabelsLoaded);
        b.add(
          const WaChatLabelsToggleRequested(
            waLabelId: '1000',
            associate: false,
          ),
        );
      },
      skip: 1,
      expect: () => <Matcher>[
        isA<WaChatLabelsMutating>().having(
          (s) => s.associated.contains('1000'),
          'optimista quitado',
          isFalse,
        ),
        isA<WaChatLabelsMutationFailed>().having(
          (s) => s.associated.contains('1000'),
          'rollback',
          isTrue,
        ),
      ],
    );
  });

  group('realtime CHAT', () {
    test('un evento CHAT de este chat actualiza el set', () async {
      stubLoad();
      when(() => repo.liveEvents('b1')).thenAnswer((_) => live.stream);
      final bloc = build()..add(const WaChatLabelsLoadRequested());
      await bloc.stream.firstWhere((s) => s is WaChatLabelsLoaded);

      // Otro dispositivo asocia 1001 a c1.
      live.add(
        const WaChatLabelChanged(
          waLabelId: '1001',
          chatLid: 'c1',
          color: 3,
          labeled: true,
        ),
      );
      final next =
          await bloc.stream.firstWhere(
                (s) => s is WaChatLabelsLoaded && s.associated.contains('1001'),
              )
              as WaChatLabelsLoaded;
      expect(next.associated, containsAll(<String>['1000', '1001']));
      await bloc.close();
    });

    test(
      'un evento CHAT de una etiqueta fuera del catálogo se ignora (sin fantasma)',
      () async {
        stubLoad();
        when(() => repo.liveEvents('b1')).thenAnswer((_) => live.stream);
        final bloc = build()..add(const WaChatLabelsLoadRequested());
        final loaded =
            await bloc.stream.firstWhere((s) => s is WaChatLabelsLoaded)
                as WaChatLabelsLoaded;

        final states = <WaChatLabelsState>[];
        final sub = bloc.stream.listen(states.add);
        // '9999' no está en el catálogo [1000,1001]: añadirlo sería invisible.
        live.add(
          const WaChatLabelChanged(
            waLabelId: '9999',
            chatLid: 'c1',
            color: 3,
            labeled: true,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(states, isEmpty);
        expect(loaded.associated, <String>{'1000'});
        await sub.cancel();
        await bloc.close();
      },
    );

    test('reconexión refetcha catálogo Y asociaciones', () async {
      var catalogCalls = 0;
      when(() => repo.listCatalog('b1')).thenAnswer((_) async {
        catalogCalls++;
        return catalogCalls == 1
            ? <WaLabel>[_wa(), _wa(id: '1001')]
            : <WaLabel>[_wa(), _wa(id: '1001'), _wa(id: '1002')];
      });
      when(() => repo.listChatAssocs('b1')).thenAnswer(
        (_) async => <WaChatAssoc>[
          const WaChatAssoc(chatLid: 'c1', waLabelId: '1002', labeled: true),
        ],
      );
      when(() => repo.liveEvents('b1')).thenAnswer((_) => live.stream);
      final bloc = build()..add(const WaChatLabelsLoadRequested());
      await bloc.stream.firstWhere((s) => s is WaChatLabelsLoaded);

      live.add(const WaLabelReconnected());

      final next =
          await bloc.stream.firstWhere(
                (s) => s is WaChatLabelsLoaded && s.catalog.length == 3,
              )
              as WaChatLabelsLoaded;
      expect(next.catalog.map((l) => l.waLabelId), contains('1002'));
      expect(next.associated, <String>{'1002'});
      expect(catalogCalls, 2); // refetcha el catálogo, no solo las asociaciones
      await bloc.close();
    });

    test('un evento CHAT de OTRO chat se ignora', () async {
      stubLoad();
      when(() => repo.liveEvents('b1')).thenAnswer((_) => live.stream);
      final bloc = build()..add(const WaChatLabelsLoadRequested());
      final loaded =
          await bloc.stream.firstWhere((s) => s is WaChatLabelsLoaded)
              as WaChatLabelsLoaded;

      final states = <WaChatLabelsState>[];
      final sub = bloc.stream.listen(states.add);
      live.add(
        const WaChatLabelChanged(
          waLabelId: '1001',
          chatLid: 'OTRO',
          color: 3,
          labeled: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(states, isEmpty);
      expect(loaded.associated, <String>{'1000'});
      await sub.cancel();
      await bloc.close();
    });
  });

  group('siembra desde caché', () {
    WaChatLabelsBloc seeded({
      List<WaLabel>? catalog,
      Set<String>? associated,
    }) => WaChatLabelsBloc(
      repo: repo,
      botId: 'b1',
      chatLid: 'c1',
      kind: ConversationKind.dm,
      seedCatalog: catalog ?? <WaLabel>[_wa(), _wa(id: '1001')],
      seedAssociated: associated ?? const <String>{'1000'},
    );

    test('arranca en Loaded con la semilla, sin estado de carga', () {
      final bloc = seeded();
      final s = bloc.state as WaChatLabelsLoaded;
      expect(s.catalog.map((l) => l.waLabelId), <String>['1000', '1001']);
      expect(s.associated, <String>{'1000'});
      addTearDown(bloc.close);
    });

    test('la semilla descarta tombstones del catálogo', () {
      final bloc = seeded(
        catalog: <WaLabel>[_wa(), _wa(id: '1001', deleted: true)],
      );
      final s = bloc.state as WaChatLabelsLoaded;
      expect(s.catalog.map((l) => l.waLabelId), <String>['1000']);
      addTearDown(bloc.close);
    });

    test(
      'sembrado: NO re-consulta HTTP al cargar, pero sí engancha realtime',
      () async {
        when(() => repo.liveEvents('b1')).thenAnswer((_) => live.stream);
        final bloc = seeded()..add(const WaChatLabelsLoadRequested());
        // Deja correr el handler (asíncrono) antes de verificar.
        await Future<void>.delayed(const Duration(milliseconds: 20));

        verifyNever(() => repo.listCatalog(any()));
        verifyNever(() => repo.listChatAssocs(any()));
        verify(() => repo.liveEvents('b1')).called(1);
        expect(bloc.state, isA<WaChatLabelsLoaded>());
        await bloc.close();
      },
    );

    test(
      'semilla con catálogo vacío: cae a la consulta HTTP (no distingue '
      'vacío-real de degradado)',
      () async {
        stubLoad();
        when(() => repo.liveEvents('b1')).thenAnswer((_) => live.stream);
        final bloc = seeded(catalog: <WaLabel>[])
          ..add(const WaChatLabelsLoadRequested());
        await bloc.stream.firstWhere((s) => s is WaChatLabelsLoaded);

        verify(() => repo.listCatalog('b1')).called(1);
        verify(() => repo.listChatAssocs('b1')).called(1);
        await bloc.close();
      },
    );

    test('sin semilla: re-consulta HTTP como siempre (camino del hilo)', () async {
      stubLoad();
      when(() => repo.liveEvents('b1')).thenAnswer((_) => live.stream);
      final bloc = build()..add(const WaChatLabelsLoadRequested());
      await bloc.stream.firstWhere((s) => s is WaChatLabelsLoaded);

      verify(() => repo.listCatalog('b1')).called(1);
      verify(() => repo.listChatAssocs('b1')).called(1);
      await bloc.close();
    });
  });
}
