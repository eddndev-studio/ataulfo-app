import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_page_container.dart';
import 'package:ataulfo/core/design/widgets/app_page_header.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/calendar/domain/entities/appointment.dart';
import 'package:ataulfo/features/calendar/domain/failures/calendar_failure.dart';
import 'package:ataulfo/features/calendar/presentation/bloc/agenda_cubit.dart';
import 'package:ataulfo/features/calendar/presentation/pages/agenda_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAgendaCubit extends MockCubit<AgendaState> implements AgendaCubit {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

Appointment _appt(String id, int hour) => Appointment(
  id: id,
  eventTypeId: 'et1',
  eventTypeName: 'Consulta',
  botId: null,
  chatLid: null,
  customerName: 'Ana',
  note: '',
  startAt: DateTime.utc(2026, 7, 15, hour, 0),
  endAt: DateTime.utc(2026, 7, 15, hour, 30),
  status: AppointmentStatus.confirmed,
  createdBy: AppointmentCreatedBy.operator,
);

AgendaState _state({
  required AgendaStatus status,
  List<Appointment> appointments = const <Appointment>[],
  CalendarFailure? failure,
}) => AgendaState(
  day: DateTime(2026, 7, 15),
  status: status,
  appointments: appointments,
  failure: failure,
  mutating: false,
);

void main() {
  late _MockAgendaCubit cubit;

  setUp(() {
    cubit = _MockAgendaCubit();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: BlocProvider<AgendaCubit>.value(
        value: cubit,
        child: const Scaffold(body: AgendaPage()),
      ),
    ),
  );

  testWidgets('loading → spinner', (tester) async {
    when(() => cubit.state).thenReturn(_state(status: AgendaStatus.loading));
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('usa un header neutro compacto para Agenda', (tester) async {
    when(() => cubit.state).thenReturn(_state(status: AgendaStatus.loaded));

    await pump(tester);

    expect(find.byType(AppPageHeader), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppPageHeader),
        matching: find.text('Agenda'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('loaded vacío → empty state', (tester) async {
    when(() => cubit.state).thenReturn(_state(status: AgendaStatus.loaded));
    await pump(tester);
    expect(find.byType(AppPrimaryPageContainer), findsOneWidget);
    expect(find.byKey(const Key('agenda.empty')), findsOneWidget);
  });

  testWidgets('loaded con citas → una tile por cita', (tester) async {
    when(() => cubit.state).thenReturn(
      _state(
        status: AgendaStatus.loaded,
        appointments: <Appointment>[_appt('a', 9), _appt('b', 11)],
      ),
    );
    await pump(tester);
    expect(find.byKey(const Key('agenda.appointment.a')), findsOneWidget);
    expect(find.byKey(const Key('agenda.appointment.b')), findsOneWidget);
  });

  testWidgets('error → mensaje y retry dispara load', (tester) async {
    when(() => cubit.state).thenReturn(
      _state(
        status: AgendaStatus.error,
        failure: const CalendarNetworkFailure(),
      ),
    );
    when(() => cubit.load()).thenAnswer((_) async {});
    await pump(tester);
    expect(find.text('No se pudo cargar la agenda.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    verify(() => cubit.load()).called(1);
  });

  testWidgets('flechas de día disparan prevDay / nextDay', (tester) async {
    when(() => cubit.state).thenReturn(_state(status: AgendaStatus.loaded));
    when(() => cubit.prevDay()).thenAnswer((_) async {});
    when(() => cubit.nextDay()).thenAnswer((_) async {});
    await pump(tester);
    await tester.tap(find.byKey(const Key('agenda.prev_day')));
    await tester.tap(find.byKey(const Key('agenda.next_day')));
    verify(() => cubit.prevDay()).called(1);
    verify(() => cubit.nextDay()).called(1);
  });

  testWidgets('gestión de Agenda vive en su menú contextual', (tester) async {
    when(() => cubit.state).thenReturn(_state(status: AgendaStatus.loaded));
    var eventTypes = 0;
    var businessHours = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<AgendaCubit>.value(
          value: cubit,
          child: Scaffold(
            body: AgendaPage(
              onManageEventTypes: () => eventTypes++,
              onManageBusinessHours: () => businessHours++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('agenda.manage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agenda.manage.event_types')));
    await tester.pumpAndSettle();
    expect(eventTypes, 1);

    await tester.tap(find.byKey(const Key('agenda.manage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agenda.manage.business_hours')));
    await tester.pumpAndSettle();
    expect(businessHours, 1);
  });

  testWidgets(
    'con onOpenSettings el avatar del header usa la identidad y navega a Ajustes',
    (tester) async {
      when(() => cubit.state).thenReturn(_state(status: AgendaStatus.loaded));
      final authBloc = _MockAuthBloc();
      when(() => authBloc.state).thenReturn(
        const AuthAuthenticated(
          Identity(
            userId: 'u1',
            orgId: 'o1',
            role: 'OWNER',
            email: 'ana@example.com',
            emailVerified: true,
          ),
        ),
      );
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<AgendaCubit>.value(value: cubit),
              BlocProvider<AuthBloc>.value(value: authBloc),
            ],
            child: Scaffold(
              body: AgendaPage(onOpenSettings: () => opened = true),
            ),
          ),
        ),
      );
      // La inicial del operador ('A' de "ana") aparece en el avatar del header.
      expect(find.text('A'), findsOneWidget);
      await tester.tap(find.text('A'));
      expect(opened, isTrue);
    },
  );

  testWidgets('tap en una cita abre el detalle', (tester) async {
    when(() => cubit.state).thenReturn(
      _state(
        status: AgendaStatus.loaded,
        appointments: <Appointment>[_appt('a', 9)],
      ),
    );
    await pump(tester);
    await tester.tap(find.byKey(const Key('agenda.appointment.a')));
    await tester.pumpAndSettle();
    // Acciones del detalle sobre una cita confirmada.
    expect(find.byKey(const Key('agenda.detail.complete')), findsOneWidget);
    expect(find.byKey(const Key('agenda.detail.cancel')), findsOneWidget);
  });
}
