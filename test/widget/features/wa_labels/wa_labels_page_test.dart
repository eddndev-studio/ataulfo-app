import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_swatch_icon.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/failures/wa_labels_failure.dart';
import 'package:ataulfo/features/wa_labels/presentation/bloc/wa_labels_bloc.dart';
import 'package:ataulfo/features/wa_labels/presentation/pages/wa_labels_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<WaLabelsEvent, WaLabelsState>
    implements WaLabelsBloc {}

WaLabel _label({
  String id = '1000',
  String name = 'VIP',
  int color = 3,
  bool deleted = false,
}) => WaLabel(waLabelId: id, name: name, color: color, deleted: deleted);

void main() {
  setUpAll(() {
    registerFallbackValue(const WaLabelsLoadRequested());
  });

  late _MockBloc bloc;

  setUp(() => bloc = _MockBloc());

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<WaLabelsBloc>.value(
      value: bloc,
      child: const WaLabelsPage(),
    ),
  );

  void stub(WaLabelsState state) {
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, Stream<WaLabelsState>.value(state), initialState: state);
  }

  testWidgets('Loading → spinner', (tester) async {
    stub(const WaLabelsLoading());
    await tester.pumpWidget(host());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Loaded → pinta nombres + swatches, oculta tombstones', (
    tester,
  ) async {
    stub(
      WaLabelsLoaded(
        labels: <WaLabel>[
          _label(name: 'Cliente VIP', color: 3),
          _label(id: '1001', name: 'Spam', color: 0),
          _label(id: '1002', name: 'Borrada', deleted: true),
        ],
        isRefreshing: false,
      ),
    );
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('Cliente VIP'), findsOneWidget);
    expect(find.text('Spam'), findsOneWidget);
    // El tombstone no se pinta.
    expect(find.text('Borrada'), findsNothing);
    // Un glifo tintado por etiqueta activa (2), no por el tombstone.
    expect(find.byType(AppSwatchIcon), findsNWidgets(2));
  });

  testWidgets('Loaded sin activas (solo tombstones) → vista vacía', (
    tester,
  ) async {
    stub(
      WaLabelsLoaded(
        labels: <WaLabel>[_label(deleted: true)],
        isRefreshing: false,
      ),
    );
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.byType(AppSwatchIcon), findsNothing);
    expect(find.byKey(const Key('wa_labels.empty')), findsOneWidget);
    // Sin etiquetas no hay nada que vincular: el launcher tampoco se monta.
    expect(find.byKey(const Key('wa_labels.mappings')), findsNothing);
  });

  testWidgets('Failed → error + Reintentar despacha load', (tester) async {
    stub(const WaLabelsFailed(WaLabelsServerFailure()));
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.byKey(const Key('wa_labels.error')), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    verify(() => bloc.add(const WaLabelsLoadRequested())).called(1);
  });

  testWidgets('el launcher de Vínculos vive en el cuerpo como card visible, '
      'no escondido en el AppBar', (tester) async {
    stub(WaLabelsLoaded(labels: <WaLabel>[_label()], isRefreshing: false));
    await tester.pumpWidget(host());
    await tester.pump();

    final launcher = find.byKey(const Key('wa_labels.mappings'));
    expect(launcher, findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: launcher),
      findsNothing,
      reason:
          'Un icono de AppBar es una affordance invisible para LA feature '
          'que convierte etiquetas en automatizaciones.',
    );
    expect(find.text('Vínculos con etiquetas internas'), findsOneWidget);
  });

  testWidgets('FAB de crear ausente en Loading', (tester) async {
    stub(const WaLabelsLoading());
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('wa_labels.create')), findsNothing);
  });

  testWidgets('FAB de crear presente en Loaded', (tester) async {
    stub(WaLabelsLoaded(labels: <WaLabel>[_label()], isRefreshing: false));
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.byKey(const Key('wa_labels.create')), findsOneWidget);
  });

  testWidgets('FAB abre el sheet de creación', (tester) async {
    stub(WaLabelsLoaded(labels: <WaLabel>[_label()], isRefreshing: false));
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.tap(find.byKey(const Key('wa_labels.create')));
    await tester.pumpAndSettle();
    expect(find.text('Nueva etiqueta'), findsOneWidget);
  });

  testWidgets(
    'las etiquetas viven en UNA card con dividers; el launcher conserva '
    'su card propia',
    (tester) async {
      stub(
        WaLabelsLoaded(
          labels: <WaLabel>[
            _label(name: 'Cliente VIP', color: 3),
            _label(id: '1001', name: 'Spam', color: 0),
          ],
          isRefreshing: false,
        ),
      );
      await tester.pumpWidget(host());
      await tester.pump();

      // Una sola card contiene ambas filas; entre filas hay divider hairline.
      final cardWithTiles = find.ancestor(
        of: find.byKey(const Key('wa_labels.tile.1000')),
        matching: find.byType(AppCard),
      );
      expect(cardWithTiles, findsOneWidget);
      expect(
        find.descendant(
          of: cardWithTiles,
          matching: find.byKey(const Key('wa_labels.tile.1001')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cardWithTiles, matching: find.byType(Divider)),
        findsOneWidget,
      );
      // El launcher de vínculos es un destino de navegación, no un item del
      // catálogo: NO se apila dentro de la card de etiquetas.
      expect(
        find.descendant(
          of: cardWithTiles,
          matching: find.byKey(const Key('wa_labels.mappings')),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('el scroll despeja el FAB de crear al fondo', (tester) async {
    stub(WaLabelsLoaded(labels: <WaLabel>[_label()], isRefreshing: false));
    await tester.pumpWidget(host());
    await tester.pump();

    final list = tester.widget<ListView>(find.byType(ListView));
    final resolved = list.padding!.resolve(TextDirection.ltr);
    expect(resolved.bottom, greaterThanOrEqualTo(AppTokens.fabClearance));
  });

  testWidgets('tap en una etiqueta abre el sheet de edición de esa etiqueta', (
    tester,
  ) async {
    stub(
      WaLabelsLoaded(
        labels: <WaLabel>[_label(name: 'Soporte', color: 3)],
        isRefreshing: false,
      ),
    );
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.tap(find.text('Soporte'));
    await tester.pumpAndSettle();
    expect(find.text('Editar etiqueta'), findsOneWidget);
    // El nombre llega precargado al sheet (distinto del hint 'Cliente VIP').
    expect(find.widgetWithText(TextField, 'Soporte'), findsOneWidget);
  });
}
