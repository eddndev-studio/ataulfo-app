import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/failures/wa_labels_failure.dart';
import 'package:ataulfo/features/wa_labels/presentation/bloc/wa_label_mapping_bloc.dart';
import 'package:ataulfo/features/wa_labels/presentation/widgets/wa_mapping_selector_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<WaMappingEvent, WaMappingState>
    implements WaLabelMappingBloc {}

WaLabel _wa({String id = '1000'}) =>
    WaLabel(waLabelId: id, name: 'VIP', color: 3, deleted: false);

Label _il({String id = 'uuid-vip', String name = 'Clientes top'}) =>
    Label(id: id, name: name, color: '#34B7F1', description: '');

void main() {
  setUpAll(
    () => registerFallbackValue(
      const WaMappingSetRequested(waLabelId: 'x', labelId: 'y'),
    ),
  );

  late _MockBloc bloc;
  setUp(() => bloc = _MockBloc());

  // Incluye 1001/1002 como etiquetas WhatsApp ACTIVAS: los tests que verifican
  // "tomado por OTRA etiqueta" mapean a esas, y solo los mapeos de etiquetas
  // activas bloquean (un mapeo a una WA-label ausente sería huérfano e inerte).
  WaMappingData dataWith(Map<String, String> mappings) => WaMappingData(
    waLabels: <WaLabel>[
      _wa(),
      _wa(id: '1001'),
      _wa(id: '1002'),
    ],
    mappings: mappings,
    internalLabels: <Label>[
      _il(),
      _il(id: 'uuid-spam', name: 'Spam'),
    ],
  );

  Widget host(WaLabel waLabel, {required WaMappingState state}) {
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<WaMappingState>.empty(), initialState: state);
    return MaterialApp(
      theme: AppDesignTheme.dark(),
      home: BlocProvider<WaLabelMappingBloc>.value(
        value: bloc,
        child: Scaffold(body: WaMappingSelectorSheet(waLabel: waLabel)),
      ),
    );
  }

  testWidgets('lista labels internos; tocar uno despacha SetRequested', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(_wa(), state: WaMappingLoaded(dataWith(const <String, String>{}))),
    );
    await tester.pump();
    expect(find.text('Clientes top'), findsOneWidget);
    expect(find.text('Spam'), findsOneWidget);

    await tester.tap(find.text('Spam'));
    verify(
      () => bloc.add(
        const WaMappingSetRequested(waLabelId: '1000', labelId: 'uuid-spam'),
      ),
    ).called(1);
  });

  testWidgets('cuando hay vínculo, "Quitar" despacha ClearRequested', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        _wa(),
        state: WaMappingLoaded(
          dataWith(const <String, String>{'1000': 'uuid-vip'}),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('wa_mapping_selector.remove')), findsOneWidget);
    await tester.tap(find.byKey(const Key('wa_mapping_selector.remove')));
    verify(
      () => bloc.add(const WaMappingClearRequested(waLabelId: '1000')),
    ).called(1);
  });

  testWidgets('sin vínculo, no aparece "Quitar"', (tester) async {
    await tester.pumpWidget(
      host(_wa(), state: WaMappingLoaded(dataWith(const <String, String>{}))),
    );
    await tester.pump();
    expect(find.byKey(const Key('wa_mapping_selector.remove')), findsNothing);
  });

  testWidgets('sin labels internos → mensaje para crearlos', (tester) async {
    when(() => bloc.state).thenReturn(
      WaMappingLoaded(
        WaMappingData(
          waLabels: <WaLabel>[_wa()],
          mappings: const <String, String>{},
          internalLabels: const <Label>[],
        ),
      ),
    );
    whenListen(
      bloc,
      const Stream<WaMappingState>.empty(),
      initialState: WaMappingLoaded(
        WaMappingData(
          waLabels: <WaLabel>[_wa()],
          mappings: const <String, String>{},
          internalLabels: const <Label>[],
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<WaLabelMappingBloc>.value(
          value: bloc,
          child: Scaffold(body: WaMappingSelectorSheet(waLabel: _wa())),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('No tienes etiquetas internas'), findsOneWidget);
  });

  testWidgets(
    'tras un set propio que falla con 422 → copy de label inexistente',
    (tester) async {
      final ctrl = StreamController<WaMappingState>.broadcast();
      addTearDown(ctrl.close);
      final loaded = WaMappingLoaded(dataWith(const <String, String>{}));
      when(() => bloc.state).thenReturn(loaded);
      whenListen(bloc, ctrl.stream, initialState: loaded);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: BlocProvider<WaLabelMappingBloc>.value(
            value: bloc,
            child: Scaffold(body: WaMappingSelectorSheet(waLabel: _wa())),
          ),
        ),
      );
      await tester.pump();
      // El sheet dispara su propia acción y luego el bloc emite MutationFailed.
      await tester.tap(find.text('Spam'));
      ctrl.add(
        WaMappingMutationFailed(
          dataWith(const <String, String>{}),
          const WaLabelsInvalidFailure(),
        ),
      );
      await tester.pump();
      expect(find.textContaining('ya no existe'), findsOneWidget);
    },
  );

  testWidgets('oculta un label ya vinculado a OTRA etiqueta WhatsApp', (
    tester,
  ) async {
    // "Spam" (uuid-spam) está vinculado a la WA 1001; al editar el vínculo de
    // la WA 1000 no debe ofrecerse (lo rechazaría el 409 de exclusividad 1:1).
    await tester.pumpWidget(
      host(
        _wa(),
        state: WaMappingLoaded(
          dataWith(const <String, String>{'1001': 'uuid-spam'}),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Clientes top'), findsOneWidget);
    expect(find.text('Spam'), findsNothing);
  });

  testWidgets(
    'conserva el label vinculado a ESTA etiqueta (marcado + Quitar)',
    (tester) async {
      // uuid-vip está en la propia 1000 (se conserva y se marca); uuid-spam en
      // otra (1001) ⇒ oculto.
      await tester.pumpWidget(
        host(
          _wa(),
          state: WaMappingLoaded(
            dataWith(const <String, String>{
              '1000': 'uuid-vip',
              '1001': 'uuid-spam',
            }),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Clientes top'), findsOneWidget);
      expect(find.text('Spam'), findsNothing);
      // El propio vínculo se muestra marcado (checkmark) además de removible.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        find.byKey(const Key('wa_mapping_selector.remove')),
        findsOneWidget,
      );
    },
  );

  testWidgets('vínculo a un label que ya no existe en la org → "Quitar" sigue', (
    tester,
  ) async {
    // currentId apunta a un label ausente de internalLabels (borrado en la org):
    // ninguna opción se marca, pero el operador debe poder romper el vínculo.
    await tester.pumpWidget(
      host(
        _wa(),
        state: WaMappingLoaded(
          dataWith(const <String, String>{'1000': 'uuid-ghost'}),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byKey(const Key('wa_mapping_selector.remove')), findsOneWidget);
  });

  testWidgets(
    'todas las internas tomadas por otras → copy distinto al de crear',
    (tester) async {
      await tester.pumpWidget(
        host(
          _wa(),
          state: WaMappingLoaded(
            dataWith(const <String, String>{
              '1001': 'uuid-vip',
              '1002': 'uuid-spam',
            }),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('ya están vinculadas'), findsOneWidget);
      expect(find.textContaining('No tienes etiquetas internas'), findsNothing);
    },
  );

  testWidgets('sheet nuevo sobre un MutationFailed previo NO arrastra el error', (
    tester,
  ) async {
    // El bloc page-scoped quedó en MutationFailed por una acción anterior; un
    // sheet recién abierto (sin submit propio) no debe mostrar ese error viejo.
    await tester.pumpWidget(
      host(
        _wa(),
        state: WaMappingMutationFailed(
          dataWith(const <String, String>{}),
          const WaLabelsInvalidFailure(),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('ya no existe'), findsNothing);
  });
}
