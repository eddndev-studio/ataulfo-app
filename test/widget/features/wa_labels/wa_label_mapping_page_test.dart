import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/presentation/bloc/wa_label_mapping_bloc.dart';
import 'package:ataulfo/features/wa_labels/presentation/pages/wa_label_mapping_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<WaMappingEvent, WaMappingState>
    implements WaLabelMappingBloc {}

WaLabel _wa({String id = '1000', String name = 'VIP'}) =>
    WaLabel(waLabelId: id, name: name, color: 3, deleted: false);

Label _il({String id = 'uuid-vip', String name = 'Clientes top'}) =>
    Label(id: id, name: name, color: '#34B7F1', description: '');

void main() {
  setUpAll(() => registerFallbackValue(const WaMappingLoadRequested()));

  late _MockBloc bloc;
  setUp(() => bloc = _MockBloc());

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<WaLabelMappingBloc>.value(
      value: bloc,
      child: const Scaffold(body: WaLabelMappingPage()),
    ),
  );

  void stub(WaMappingState s) {
    when(() => bloc.state).thenReturn(s);
    whenListen(bloc, Stream<WaMappingState>.value(s), initialState: s);
  }

  final data = WaMappingData(
    waLabels: <WaLabel>[
      _wa(name: 'VIP'),
      _wa(id: '1001', name: 'Soporte'),
    ],
    mappings: <String, String>{'1000': 'uuid-vip'},
    internalLabels: <Label>[_il()],
  );

  testWidgets('Loading → spinner', (tester) async {
    stub(const WaMappingLoading());
    await tester.pumpWidget(host());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Loaded ofrece pull-to-refresh', (tester) async {
    stub(WaMappingLoaded(data));
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.byType(RefreshIndicator), findsOneWidget);

    // El gesto despacha una recarga (la única vía de ver labels nuevos sin
    // salir y volver a entrar).
    await tester.fling(
      find.byType(ListView),
      const Offset(0, 300),
      1000,
    );
    // El indicador arma → dispara onRefresh tras asentar su animación.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    verify(() => bloc.add(const WaMappingLoadRequested())).called(1);
  });

  testWidgets(
    'Loaded: nota + mapeado muestra el label, sin mapear muestra aviso',
    (tester) async {
      stub(WaMappingLoaded(data));
      await tester.pumpWidget(host());
      await tester.pump();

      // Deja claro que mapear ≠ empujar a WhatsApp.
      expect(find.textContaining('no la cambia en WhatsApp'), findsOneWidget);
      // La etiqueta WA mapeada muestra el nombre del label interno.
      expect(find.text('VIP'), findsOneWidget);
      expect(find.text('Clientes top'), findsOneWidget);
      // La no mapeada muestra "Sin vincular".
      expect(find.text('Soporte'), findsOneWidget);
      expect(find.text('Sin vincular'), findsOneWidget);
    },
  );

  testWidgets(
    'mapeo colgante (label borrado) → "Vínculo roto", no "Sin vincular"',
    (tester) async {
      stub(
        WaMappingLoaded(
          WaMappingData(
            waLabels: <WaLabel>[_wa(name: 'Soporte')],
            // Mapea a un label que ya no existe en internalLabels.
            mappings: const <String, String>{'1000': 'ghost'},
            internalLabels: <Label>[_il()],
          ),
        ),
      );
      await tester.pumpWidget(host());
      await tester.pump();
      expect(find.text('Vínculo roto'), findsOneWidget);
      expect(find.text('Sin vincular'), findsNothing);
    },
  );

  testWidgets('Failed → error + Reintentar despacha load', (tester) async {
    stub(const WaMappingFailed(WaMappingError.forbidden));
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.byKey(const Key('wa_mapping.error')), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    verify(() => bloc.add(const WaMappingLoadRequested())).called(1);
  });

  testWidgets('tap en una fila abre el selector', (tester) async {
    stub(WaMappingLoaded(data));
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.tap(find.text('Soporte'));
    await tester.pumpAndSettle();
    // El selector muestra los labels internos para elegir.
    expect(find.byKey(const Key('wa_mapping_selector')), findsOneWidget);
  });
}
