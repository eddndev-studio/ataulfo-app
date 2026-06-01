import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/failures/labels_failure.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_admin_bloc.dart';
import 'package:ataulfo/features/labels/presentation/pages/labels_admin_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<LabelsAdminEvent, LabelsAdminState>
    implements LabelsAdminBloc {}

void main() {
  late _MockBloc bloc;
  setUp(() => bloc = _MockBloc());

  void seed(LabelsAdminState state) {
    when(() => bloc.state).thenReturn(state);
    whenListen(
      bloc,
      const Stream<LabelsAdminState>.empty(),
      initialState: state,
    );
  }

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<LabelsAdminBloc>.value(
      value: bloc,
      child: const Scaffold(body: LabelsAdminPage()),
    ),
  );

  testWidgets('Loading → spinner', (tester) async {
    seed(const LabelsAdminLoading());
    await tester.pumpWidget(host());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Loaded con etiquetas → pinta nombres', (tester) async {
    seed(
      const LabelsAdminLoaded(
        labels: <Label>[
          Label(id: '1', name: 'VIP', color: '#7c3aed', description: 'Oro'),
          Label(id: '2', name: 'Soporte', color: '#22c55e', description: ''),
        ],
        isRefreshing: false,
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('Oro'), findsOneWidget);
  });

  testWidgets('Loaded vacío → empty state', (tester) async {
    seed(const LabelsAdminLoaded(labels: <Label>[], isRefreshing: false));
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('labels_admin.empty')), findsOneWidget);
  });

  testWidgets('Failed → error + reintentar despacha LoadRequested', (
    tester,
  ) async {
    seed(const LabelsAdminFailed(LabelsServerFailure()));
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('labels_admin.error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('labels_admin.retry')));
    verify(() => bloc.add(const LabelsAdminLoadRequested())).called(1);
  });

  testWidgets('tocar una etiqueta abre la hoja de edición', (tester) async {
    seed(
      const LabelsAdminLoaded(
        labels: <Label>[
          Label(id: '1', name: 'VIP', color: '#7c3aed', description: ''),
        ],
        isRefreshing: false,
      ),
    );
    await tester.pumpWidget(host());
    await tester.tap(find.text('VIP'));
    await tester.pumpAndSettle();
    expect(find.text('Editar etiqueta'), findsOneWidget);
  });
}
