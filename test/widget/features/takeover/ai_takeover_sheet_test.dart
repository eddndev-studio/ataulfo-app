import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_action_row.dart';
import 'package:ataulfo/features/takeover/presentation/cubit/ai_takeover_cubit.dart';
import 'package:ataulfo/features/takeover/presentation/widgets/ai_takeover_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<AiTakeoverState>
    implements AiTakeoverCubit {}

void main() {
  late _MockCubit cubit;
  setUp(() => cubit = _MockCubit());

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: BlocProvider<AiTakeoverCubit>.value(
        value: cubit,
        child: const AiTakeoverSheet(),
      ),
    ),
  );

  testWidgets('respondiendo: muestra estado + acción "Pausar Canal aquí"', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const AiTakeoverReady(silenceIds: <String>['s1'], presentIds: <String>[]),
    );
    when(() => cubit.toggle()).thenAnswer((_) async {});
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('takeover.state')), findsOneWidget);
    expect(find.text('Pausar Canal aquí'), findsOneWidget);

    await tester.tap(find.byKey(const Key('takeover.toggle')));
    verify(() => cubit.toggle()).called(1);
  });

  testWidgets('pausado: el botón ofrece reanudar', (tester) async {
    when(() => cubit.state).thenReturn(
      const AiTakeoverReady(
        silenceIds: <String>['s1'],
        presentIds: <String>['s1'],
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('Reanudar Canal'), findsOneWidget);
  });

  testWidgets('sin etiqueta de silencio configurada: aviso, sin toggle', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const AiTakeoverReady(silenceIds: <String>[], presentIds: <String>[]),
    );
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('takeover.not_configured')), findsOneWidget);
    expect(find.byKey(const Key('takeover.toggle')), findsNothing);
  });

  testWidgets('ocupado: tocar el toggle no dispara otra acción', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const AiTakeoverReady(
        silenceIds: <String>['s1'],
        presentIds: <String>[],
        busy: true,
      ),
    );
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('takeover.toggle')));
    verifyNever(() => cubit.toggle());
  });

  testWidgets('error de carga → aviso', (tester) async {
    when(() => cubit.state).thenReturn(const AiTakeoverError());
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('takeover.error')), findsOneWidget);
  });

  group('anatomía de menú-sheet', () {
    testWidgets('H1 titleLarge y la acción es una fila de menú, no un botón', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const AiTakeoverReady(
          silenceIds: <String>['s1'],
          presentIds: <String>[],
        ),
      );
      when(() => cubit.toggle()).thenAnswer((_) async {});
      await tester.pumpWidget(host());

      final h1 = tester.widget<Text>(
        find.text('Control del Canal en este chat'),
      );
      expect(h1.style?.fontSize, AppTokens.titleLSize);

      // La acción vive como fila canónica de menú-sheet, no como botón CTA.
      final tile = tester.widget<AppActionRow>(
        find.byKey(const Key('takeover.toggle')),
      );
      expect(tile.title, 'Pausar Canal aquí');
      expect(find.byType(AppButton), findsNothing);

      await tester.tap(find.byKey(const Key('takeover.toggle')));
      verify(() => cubit.toggle()).called(1);
    });
  });
}
