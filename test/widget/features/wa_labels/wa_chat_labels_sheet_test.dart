import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/failures/wa_labels_failure.dart';
import 'package:ataulfo/features/wa_labels/presentation/bloc/wa_chat_labels_bloc.dart';
import 'package:ataulfo/features/wa_labels/presentation/widgets/wa_chat_labels_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<WaChatLabelsEvent, WaChatLabelsState>
    implements WaChatLabelsBloc {}

WaLabel _wa({String id = '1000', String name = 'VIP', int color = 3}) =>
    WaLabel(waLabelId: id, name: name, color: color, deleted: false);

void main() {
  setUpAll(
    () => registerFallbackValue(
      const WaChatLabelsToggleRequested(waLabelId: 'x', associate: true),
    ),
  );

  late _MockBloc bloc;
  setUp(() => bloc = _MockBloc());

  Widget host(WaChatLabelsState state) {
    when(() => bloc.state).thenReturn(state);
    whenListen(
      bloc,
      const Stream<WaChatLabelsState>.empty(),
      initialState: state,
    );
    return MaterialApp(
      theme: AppDesignTheme.dark(),
      home: BlocProvider<WaChatLabelsBloc>.value(
        value: bloc,
        child: const Scaffold(body: WaChatLabelsSheet()),
      ),
    );
  }

  testWidgets(
    'Loaded: lista catálogo; asociar despacha toggle(associate:true)',
    (tester) async {
      await tester.pumpWidget(
        host(
          WaChatLabelsLoaded(
            catalog: <WaLabel>[
              _wa(name: 'VIP'),
              _wa(id: '1001', name: 'Spam'),
            ],
            associated: const <String>{'1000'},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('VIP'), findsOneWidget);
      expect(find.text('Spam'), findsOneWidget);

      // 'Spam' (1001) no está asociada → tocar asocia.
      await tester.tap(find.text('Spam'));
      verify(
        () => bloc.add(
          const WaChatLabelsToggleRequested(waLabelId: '1001', associate: true),
        ),
      ).called(1);
    },
  );

  testWidgets('tocar una asociada despacha toggle(associate:false)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        WaChatLabelsLoaded(
          catalog: <WaLabel>[_wa(name: 'VIP')],
          associated: const <String>{'1000'},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('VIP'));
    verify(
      () => bloc.add(
        const WaChatLabelsToggleRequested(waLabelId: '1000', associate: false),
      ),
    ).called(1);
  });

  testWidgets('catálogo vacío → mensaje', (tester) async {
    await tester.pumpWidget(
      host(
        const WaChatLabelsLoaded(catalog: <WaLabel>[], associated: <String>{}),
      ),
    );
    await tester.pump();
    expect(find.textContaining('No hay etiquetas'), findsOneWidget);
  });

  testWidgets('MutationFailed → copy de error (NotConnected)', (tester) async {
    await tester.pumpWidget(
      host(
        WaChatLabelsMutationFailed(
          catalog: <WaLabel>[_wa()],
          associated: const <String>{},
          failure: const WaLabelsNotConnectedFailure(),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('no está conectado'), findsOneWidget);
  });

  testWidgets('Failed → error + Reintentar', (tester) async {
    await tester.pumpWidget(
      host(const WaChatLabelsFailed(WaLabelsServerFailure())),
    );
    await tester.pump();
    expect(find.byKey(const Key('wa_chat_labels.error')), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    verify(() => bloc.add(const WaChatLabelsLoadRequested())).called(1);
  });
}
