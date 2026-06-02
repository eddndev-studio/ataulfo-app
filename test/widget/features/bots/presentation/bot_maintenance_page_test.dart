import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_maintenance_bloc.dart';
import 'package:ataulfo/features/bots/presentation/pages/bot_maintenance_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<BotMaintenanceEvent, BotMaintenanceState>
    implements BotMaintenanceBloc {}

const _running = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: null,
  version: 3,
  paused: false,
  aiDisabled: false,
);

const _paused = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: null,
  version: 4,
  paused: true,
  aiDisabled: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const BotMaintenanceClearRequested());
  });

  late _MockBloc bloc;
  setUp(() => bloc = _MockBloc());

  Widget host(BotMaintenanceState state) {
    when(() => bloc.state).thenReturn(state);
    whenListen(
      bloc,
      const Stream<BotMaintenanceState>.empty(),
      initialState: state,
    );
    return MaterialApp(
      theme: AppDesignTheme.dark(),
      home: BlocProvider<BotMaintenanceBloc>.value(
        value: bloc,
        child: const Scaffold(body: BotMaintenancePage()),
      ),
    );
  }

  testWidgets('no pausado: clear/reset deshabilitados + hint de pausa', (
    tester,
  ) async {
    await tester.pumpWidget(host(const BotMaintenanceLoaded(_running)));

    final clear = tester.widget<AppButton>(
      find.byKey(const Key('bot_maint.clear')),
    );
    final reset = tester.widget<AppButton>(
      find.byKey(const Key('bot_maint.reset')),
    );
    expect(clear.onPressed, isNull); // deshabilitado
    expect(reset.onPressed, isNull);
    expect(find.textContaining('pausa'), findsWidgets);
    // Y aparece el switch de pausar (desbloqueo).
    expect(find.byKey(const Key('bot_maint.pause')), findsOneWidget);
  });

  testWidgets('pausado: clear/reset habilitados', (tester) async {
    await tester.pumpWidget(host(const BotMaintenanceLoaded(_paused)));

    final clear = tester.widget<AppButton>(
      find.byKey(const Key('bot_maint.clear')),
    );
    expect(clear.onPressed, isNotNull);
  });

  testWidgets('pausado: tap clear → confirma → ClearRequested', (tester) async {
    await tester.pumpWidget(host(const BotMaintenanceLoaded(_paused)));

    await tester.tap(find.byKey(const Key('bot_maint.clear')));
    await tester.pumpAndSettle();
    // Diálogo de confirmación.
    expect(find.byKey(const Key('bot_maint.clear_confirm')), findsOneWidget);
    verifyNever(() => bloc.add(const BotMaintenanceClearRequested()));

    await tester.tap(find.byKey(const Key('bot_maint.clear_confirm')));
    await tester.pump();
    verify(() => bloc.add(const BotMaintenanceClearRequested())).called(1);
  });

  testWidgets('no pausado: tap en el switch de pausa → PauseToggled', (
    tester,
  ) async {
    await tester.pumpWidget(host(const BotMaintenanceLoaded(_running)));

    await tester.tap(find.byKey(const Key('bot_maint.pause')));
    await tester.pump();
    verify(() => bloc.add(const BotMaintenancePauseToggled())).called(1);
  });

  testWidgets('OpFailed(NotPaused) muestra copy de "no está pausado"', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const BotMaintenanceOpFailed(_running, BotsNotPausedFailure()),
      ),
    );
    expect(find.textContaining('pausado'), findsWidgets);
  });

  testWidgets('recordatorio explícito de que el bot NO se reanuda solo', (
    tester,
  ) async {
    await tester.pumpWidget(host(const BotMaintenanceLoaded(_paused)));
    expect(find.textContaining('no se reanuda'), findsOneWidget);
  });
}
