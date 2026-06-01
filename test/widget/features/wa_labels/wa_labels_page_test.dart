import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/failures/wa_labels_failure.dart';
import 'package:ataulfo/features/wa_labels/presentation/bloc/wa_labels_bloc.dart';
import 'package:ataulfo/features/wa_labels/presentation/pages/wa_labels_page.dart';
import 'package:ataulfo/features/wa_labels/presentation/widgets/wa_label_swatch.dart';
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
      child: const Scaffold(body: WaLabelsPage()),
    ),
  );

  void stub(WaLabelsState state) {
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
    // Un swatch por etiqueta activa (2), no por el tombstone.
    expect(find.byType(WaLabelSwatch), findsNWidgets(2));
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
    expect(find.byType(WaLabelSwatch), findsNothing);
    expect(find.byKey(const Key('wa_labels.empty')), findsOneWidget);
  });

  testWidgets('Failed → error + Reintentar despacha load', (tester) async {
    stub(const WaLabelsFailed(WaLabelsServerFailure()));
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.byKey(const Key('wa_labels.error')), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    verify(() => bloc.add(const WaLabelsLoadRequested())).called(1);
  });
}
