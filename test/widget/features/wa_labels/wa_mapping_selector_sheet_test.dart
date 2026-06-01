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

  WaMappingData dataWith(Map<String, String> mappings) => WaMappingData(
    waLabels: <WaLabel>[_wa()],
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

  testWidgets('MutationFailed 422 → copy de label inexistente', (tester) async {
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
    expect(find.textContaining('ya no existe'), findsOneWidget);
  });
}
