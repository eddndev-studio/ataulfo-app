import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/calendar/domain/entities/business_hours.dart';
import 'package:ataulfo/features/calendar/presentation/bloc/business_hours_cubit.dart';
import 'package:ataulfo/features/calendar/presentation/pages/business_hours_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<BusinessHoursState>
    implements BusinessHoursCubit {}

BusinessHoursState _loaded(List<BusinessHoursSlot> working) =>
    BusinessHoursState(
      status: BusinessHoursStatus.loaded,
      working: working,
      baseline: const <BusinessHoursSlot>[],
      saving: false,
      failure: null,
    );

void main() {
  late _MockCubit cubit;

  setUp(() => cubit = _MockCubit());

  // Alto generoso: la lista de 7 días es un ListView perezoso; con un alto
  // corto los días de abajo (domingo) y el aviso al pie no se construyen.
  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<BusinessHoursCubit>.value(
          value: cubit,
          child: const Scaffold(body: BusinessHoursPage()),
        ),
      ),
    );
  }

  testWidgets('loading → spinner', (tester) async {
    when(() => cubit.state).thenReturn(const BusinessHoursState.loading());
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('loaded → una tarjeta por cada día de la semana', (tester) async {
    when(() => cubit.state).thenReturn(_loaded(const <BusinessHoursSlot>[]));
    await pump(tester);
    for (var weekday = 0; weekday <= 6; weekday++) {
      expect(find.byKey(Key('hours.day.$weekday')), findsOneWidget);
    }
    // Lunes primero en orden visual.
    expect(find.text('Lunes'), findsOneWidget);
    expect(find.text('Domingo'), findsOneWidget);
  });

  testWidgets('sin cambios válidos el guardar queda deshabilitado', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(_loaded(const <BusinessHoursSlot>[]));
    await pump(tester);
    final btn = tester.widget<AppButton>(find.byKey(const Key('hours.save')));
    expect(btn.onPressed, isNull);
  });

  testWidgets('agregar tramo dispara addSlot del día', (tester) async {
    when(() => cubit.state).thenReturn(_loaded(const <BusinessHoursSlot>[]));
    await pump(tester);
    // Lunes = índice de wire 1.
    await tester.ensureVisible(find.byKey(const Key('hours.add.1')));
    await tester.tap(find.byKey(const Key('hours.add.1')));
    verify(() => cubit.addSlot(1)).called(1);
  });

  testWidgets('tramos inválidos muestran el aviso', (tester) async {
    when(() => cubit.state).thenReturn(
      _loaded(const <BusinessHoursSlot>[
        // apertura >= cierre
        BusinessHoursSlot(weekday: 1, openMin: 800, closeMin: 700),
      ]),
    );
    await pump(tester);
    expect(find.byKey(const Key('hours.invalid')), findsOneWidget);
  });
}
