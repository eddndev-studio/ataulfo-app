import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/calendar/domain/entities/event_type.dart';
import 'package:ataulfo/features/calendar/presentation/bloc/booking_cubit.dart';
import 'package:ataulfo/features/calendar/presentation/pages/booking_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<BookingState> implements BookingCubit {}

const _et = EventType(
  id: 'et1',
  name: 'Consulta',
  description: '',
  durationMin: 30,
  active: true,
);

BookingState _base({
  BookingTypesStatus typesStatus = BookingTypesStatus.loaded,
  List<EventType> eventTypes = const <EventType>[_et],
  EventType? selectedEventType,
  DateTime? date,
  SlotsStatus slotsStatus = SlotsStatus.idle,
  String? slotsErrorMessage,
}) => BookingState(
  typesStatus: typesStatus,
  eventTypes: eventTypes,
  selectedEventType: selectedEventType,
  date: date,
  slotsStatus: slotsStatus,
  slots: const <DateTime>[],
  selectedSlot: null,
  submitting: false,
  slotsErrorMessage: slotsErrorMessage,
);

void main() {
  setUpAll(() => registerFallbackValue(_et));

  late _MockCubit cubit;

  setUp(() => cubit = _MockCubit());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: BlocProvider<BookingCubit>.value(
        value: cubit,
        child: const Scaffold(body: BookingPage()),
      ),
    ),
  );

  testWidgets('cargando tipos → spinner', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(_base(typesStatus: BookingTypesStatus.loading));
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('sin tipos activos → mensaje guía', (tester) async {
    when(() => cubit.state).thenReturn(_base(eventTypes: const <EventType>[]));
    await pump(tester);
    expect(find.textContaining('No hay tipos de cita activos'), findsOneWidget);
  });

  testWidgets('tipos cargados → chip por tipo; tocarlo selecciona', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(_base());
    when(() => cubit.selectEventType(any())).thenReturn(null);
    await pump(tester);
    expect(find.byKey(const Key('booking.type.et1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('booking.type.et1')));
    verify(() => cubit.selectEventType(_et)).called(1);
  });

  testWidgets('con tipo elegido aparece el paso de fecha', (tester) async {
    when(() => cubit.state).thenReturn(_base(selectedEventType: _et));
    await pump(tester);
    expect(find.byKey(const Key('booking.pick_date')), findsOneWidget);
  });

  testWidgets('fecha rechazada → mensaje específico, sin reintentar', (
    tester,
  ) async {
    const rejected = 'La fecha es demasiado lejana. Elige una más cercana.';
    when(() => cubit.state).thenReturn(
      _base(
        selectedEventType: _et,
        date: DateTime(2027, 1, 1),
        slotsStatus: SlotsStatus.error,
        slotsErrorMessage: rejected,
      ),
    );
    await pump(tester);
    expect(find.text(rejected), findsOneWidget);
    expect(find.text('No se pudo cargar la disponibilidad.'), findsNothing);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('error transitorio de disponibilidad → genérico con reintentar', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      _base(
        selectedEventType: _et,
        date: DateTime(2026, 7, 15),
        slotsStatus: SlotsStatus.error,
      ),
    );
    await pump(tester);
    expect(find.text('No se pudo cargar la disponibilidad.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
