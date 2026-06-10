import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/failures/labels_failure.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_admin_bloc.dart';
import 'package:ataulfo/features/labels/presentation/widgets/label_color_palette.dart';
import 'package:ataulfo/features/labels/presentation/widgets/label_edit_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<LabelsAdminEvent, LabelsAdminState>
    implements LabelsAdminBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const LabelsAdminCreateRequested(
        name: 'x',
        color: '#000000',
        description: '',
      ),
    );
  });

  late _MockBloc bloc;
  setUp(() => bloc = _MockBloc());

  const loaded = LabelsAdminLoaded(
    labels: <Label>[
      Label(
        id: '1',
        name: 'VIP',
        color: '#7c3aed',
        description: 'Cliente prioritario',
      ),
    ],
    isRefreshing: false,
  );

  Widget host(Label? editing, {LabelsAdminState? state}) {
    when(() => bloc.state).thenReturn(state ?? loaded);
    whenListen(
      bloc,
      const Stream<LabelsAdminState>.empty(),
      initialState: state ?? loaded,
    );
    return MaterialApp(
      theme: AppDesignTheme.dark(),
      home: BlocProvider<LabelsAdminBloc>.value(
        value: bloc,
        child: Scaffold(body: LabelEditSheet(editing: editing)),
      ),
    );
  }

  testWidgets('los swatches de color dan área táctil ≥44px', (tester) async {
    await tester.pumpWidget(host(null));

    final swatch = find.byKey(const Key('label_palette.0'));
    expect(swatch, findsOneWidget);
    final size = tester.getSize(swatch);
    expect(size.width, greaterThanOrEqualTo(44.0));
    expect(size.height, greaterThanOrEqualTo(44.0));
  });

  testWidgets('crear: título, sin delete, submit deshabilitado sin nombre', (
    tester,
  ) async {
    await tester.pumpWidget(host(null));
    expect(find.text('Nueva etiqueta'), findsOneWidget);
    expect(find.byKey(const Key('label_edit.delete')), findsNothing);

    await tester.tap(find.byKey(const Key('label_edit.submit')));
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('crear: nombre + color + descripción → CreateRequested', (
    tester,
  ) async {
    await tester.pumpWidget(host(null));
    await tester.enterText(find.byKey(const Key('label_edit.name')), 'Soporte');
    await tester.enterText(
      find.byKey(const Key('label_edit.description')),
      'Tickets',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('label_palette.3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('label_edit.submit')));

    verify(
      () => bloc.add(
        LabelsAdminCreateRequested(
          name: 'Soporte',
          color: LabelColorPalette.hexColors[3],
          description: 'Tickets',
        ),
      ),
    ).called(1);
  });

  testWidgets(
    'editar: título, campos precargados, delete visible → UpdateRequested',
    (tester) async {
      const editing = Label(
        id: '1',
        name: 'VIP',
        color: '#7c3aed',
        description: 'Cliente prioritario',
      );
      await tester.pumpWidget(host(editing));
      expect(find.text('Editar etiqueta'), findsOneWidget);
      expect(find.byKey(const Key('label_edit.delete')), findsOneWidget);
      expect(find.widgetWithText(TextField, 'VIP'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Cliente prioritario'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('label_edit.name')),
        'VIP Oro',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('label_edit.submit')));

      verify(
        () => bloc.add(
          const LabelsAdminUpdateRequested(
            id: '1',
            name: 'VIP Oro',
            color: '#7c3aed',
            description: 'Cliente prioritario',
          ),
        ),
      ).called(1);
    },
  );

  testWidgets('editar: delete → confirma → DeleteRequested', (tester) async {
    const editing = Label(
      id: '1',
      name: 'VIP',
      color: '#7c3aed',
      description: '',
    );
    await tester.pumpWidget(host(editing));
    await tester.tap(find.byKey(const Key('label_edit.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('label_edit.delete_confirm')));
    await tester.pump();

    verify(() => bloc.add(const LabelsAdminDeleteRequested(id: '1'))).called(1);
  });

  testWidgets('MutationFailed duplicado: muestra copy de nombre en uso', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        null,
        state: LabelsAdminMutationFailed(
          loaded.labels,
          const LabelsDuplicateNameFailure(),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Ya existe'), findsOneWidget);
  });

  testWidgets('MutationFailed validación: muestra copy de datos inválidos', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        null,
        state: LabelsAdminMutationFailed(
          loaded.labels,
          const LabelsValidationFailure(),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Revisa'), findsOneWidget);
  });

  testWidgets('éxito (Loaded tras submit) cierra el sheet', (tester) async {
    final ctrl = StreamController<LabelsAdminState>.broadcast();
    addTearDown(ctrl.close);
    when(() => bloc.state).thenReturn(loaded);
    whenListen(bloc, ctrl.stream, initialState: loaded);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<LabelsAdminBloc>.value(
          value: bloc,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => BlocProvider<LabelsAdminBloc>.value(
                    value: bloc,
                    child: const LabelEditSheet(editing: null),
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

    await tester.enterText(find.byKey(const Key('label_edit.name')), 'X');
    await tester.pump();
    await tester.tap(find.byKey(const Key('label_edit.submit')));
    ctrl.add(LabelsAdminLoaded(labels: loaded.labels, isRefreshing: false));
    await tester.pumpAndSettle();
    expect(find.text('Nueva etiqueta'), findsNothing);
  });
}
