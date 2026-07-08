import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_switch.dart';
import 'package:ataulfo/features/calendar/domain/entities/event_type.dart';
import 'package:ataulfo/features/calendar/presentation/bloc/event_types_cubit.dart';
import 'package:ataulfo/features/calendar/presentation/pages/event_types_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<EventTypesState>
    implements EventTypesCubit {}

const _et = EventType(
  id: 'et1',
  name: 'Consulta',
  description: '',
  durationMin: 30,
  active: true,
);

EventTypesState _state({
  required EventTypesStatus status,
  List<EventType> items = const <EventType>[],
}) => EventTypesState(
  status: status,
  items: items,
  failure: null,
  mutating: false,
);

void main() {
  setUpAll(() => registerFallbackValue(_et));

  late _MockCubit cubit;

  setUp(() => cubit = _MockCubit());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: BlocProvider<EventTypesCubit>.value(
        value: cubit,
        child: const Scaffold(body: EventTypesPage()),
      ),
    ),
  );

  testWidgets('loading → spinner', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(_state(status: EventTypesStatus.loading));
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('vacío → empty state + botón crear', (tester) async {
    when(() => cubit.state).thenReturn(_state(status: EventTypesStatus.loaded));
    await pump(tester);
    expect(find.byKey(const Key('event_types.empty')), findsOneWidget);
    expect(find.byKey(const Key('event_types.create')), findsOneWidget);
  });

  testWidgets('con tipos → fila por tipo con duración', (tester) async {
    when(() => cubit.state).thenReturn(
      _state(status: EventTypesStatus.loaded, items: <EventType>[_et]),
    );
    await pump(tester);
    expect(find.byKey(const Key('event_types.row.et1')), findsOneWidget);
    expect(find.text('Consulta'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
  });

  testWidgets('botón crear abre el formulario', (tester) async {
    when(() => cubit.state).thenReturn(_state(status: EventTypesStatus.loaded));
    await pump(tester);
    await tester.tap(find.byKey(const Key('event_types.create')));
    await tester.pumpAndSettle();
    // Campos únicos del formulario de alta (el título se anima y puede matchear
    // dos veces durante la transición de la hoja).
    expect(find.byKey(const Key('event_type.name')), findsOneWidget);
    expect(find.text('Crear tipo'), findsOneWidget);
  });

  testWidgets('toggle de activo dispara setActive', (tester) async {
    when(() => cubit.state).thenReturn(
      _state(status: EventTypesStatus.loaded, items: <EventType>[_et]),
    );
    when(() => cubit.setActive(any(), any())).thenAnswer((_) async => null);
    await pump(tester);
    await tester.tap(find.byType(AppSwitch).first);
    verify(() => cubit.setActive(_et, false)).called(1);
  });
}
