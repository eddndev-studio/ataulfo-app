import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/failures/wa_labels_failure.dart';
import 'package:ataulfo/features/wa_labels/presentation/bloc/wa_labels_bloc.dart';
import 'package:ataulfo/features/wa_labels/presentation/widgets/wa_label_edit_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<WaLabelsEvent, WaLabelsState>
    implements WaLabelsBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const WaLabelsAddRequested(name: 'x', color: 0));
  });

  late _MockBloc bloc;

  setUp(() => bloc = _MockBloc());

  final loaded = WaLabelsLoaded(
    labels: <WaLabel>[
      const WaLabel(waLabelId: '1000', name: 'VIP', color: 3, deleted: false),
    ],
    isRefreshing: false,
  );

  Widget host(WaLabel? editing, {WaLabelsState? state}) {
    when(() => bloc.state).thenReturn(state ?? loaded);
    whenListen(
      bloc,
      const Stream<WaLabelsState>.empty(),
      initialState: state ?? loaded,
    );
    return MaterialApp(
      theme: AppDesignTheme.dark(),
      home: BlocProvider<WaLabelsBloc>.value(
        value: bloc,
        child: Scaffold(body: WaLabelEditSheet(editing: editing)),
      ),
    );
  }

  testWidgets('crear: título, sin delete, submit deshabilitado sin nombre', (
    tester,
  ) async {
    await tester.pumpWidget(host(null));
    expect(find.text('Nueva etiqueta'), findsOneWidget);
    expect(find.byKey(const Key('wa_edit.delete')), findsNothing);

    // Submit con nombre vacío no despacha.
    await tester.tap(find.byKey(const Key('wa_edit.submit')));
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('crear: nombre + color elegido → AddRequested', (tester) async {
    await tester.pumpWidget(host(null));
    await tester.enterText(find.byKey(const Key('wa_edit.name')), 'Soporte');
    await tester.pump();
    // Elige el índice de paleta 5.
    await tester.tap(find.byKey(const Key('wa_palette.5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('wa_edit.submit')));

    verify(
      () => bloc.add(const WaLabelsAddRequested(name: 'Soporte', color: 5)),
    ).called(1);
  });

  testWidgets(
    'editar: título, nombre precargado, delete visible → UpdateRequested',
    (tester) async {
      const editing = WaLabel(
        waLabelId: '1000',
        name: 'VIP',
        color: 3,
        deleted: false,
      );
      await tester.pumpWidget(host(editing));
      expect(find.text('Editar etiqueta'), findsOneWidget);
      expect(find.byKey(const Key('wa_edit.delete')), findsOneWidget);
      expect(find.widgetWithText(TextField, 'VIP'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('wa_edit.name')), 'VIP Oro');
      await tester.pump();
      await tester.tap(find.byKey(const Key('wa_edit.submit')));

      verify(
        () => bloc.add(
          const WaLabelsUpdateRequested(
            waLabelId: '1000',
            name: 'VIP Oro',
            color: 3,
          ),
        ),
      ).called(1);
    },
  );

  testWidgets('editar: delete → confirma → DeleteRequested', (tester) async {
    const editing = WaLabel(
      waLabelId: '1000',
      name: 'VIP',
      color: 3,
      deleted: false,
    );
    await tester.pumpWidget(host(editing));
    await tester.tap(find.byKey(const Key('wa_edit.delete')));
    await tester.pumpAndSettle();
    // Diálogo de confirmación.
    await tester.tap(find.byKey(const Key('wa_edit.delete_confirm')));
    await tester.pump();

    verify(
      () => bloc.add(const WaLabelsDeleteRequested(waLabelId: '1000')),
    ).called(1);
  });

  testWidgets('MutationFailed: muestra el copy del failure (NotConnected)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        null,
        state: WaLabelsMutationFailed(
          loaded.labels,
          const WaLabelsNotConnectedFailure(),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('no está conectado'), findsOneWidget);
  });

  testWidgets('éxito (Loaded tras submit) cierra el sheet', (tester) async {
    final ctrl = StreamController<WaLabelsState>.broadcast();
    addTearDown(ctrl.close);
    when(() => bloc.state).thenReturn(loaded);
    whenListen(bloc, ctrl.stream, initialState: loaded);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<WaLabelsBloc>.value(
          value: bloc,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => BlocProvider<WaLabelsBloc>.value(
                    value: bloc,
                    child: const WaLabelEditSheet(editing: null),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva etiqueta'), findsOneWidget);

    // Submit (con nombre) y luego el bloc emite Loaded → el sheet se cierra.
    await tester.enterText(find.byKey(const Key('wa_edit.name')), 'X');
    await tester.pump();
    await tester.tap(find.byKey(const Key('wa_edit.submit')));
    ctrl.add(WaLabelsLoaded(labels: loaded.labels, isRefreshing: false));
    await tester.pumpAndSettle();
    expect(find.text('Nueva etiqueta'), findsNothing); // se cerró
  });
}
