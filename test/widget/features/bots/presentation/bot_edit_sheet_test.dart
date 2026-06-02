import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_detail_bloc.dart';
import 'package:ataulfo/features/bots/presentation/widgets/bot_edit_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<BotDetailEvent, BotDetailState>
    implements BotDetailBloc {}

const _bot = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: '5215512345678',
  version: 3,
  paused: false,
  aiDisabled: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const BotDetailUpdateRequested());
  });

  late _MockBloc bloc;
  setUp(() => bloc = _MockBloc());

  Widget host({BotDetailState? state, Bot editing = _bot}) {
    final s = state ?? const BotDetailLoaded(_bot);
    when(() => bloc.state).thenReturn(s);
    whenListen(bloc, const Stream<BotDetailState>.empty(), initialState: s);
    return MaterialApp(
      theme: AppDesignTheme.dark(),
      home: BlocProvider<BotDetailBloc>.value(
        value: bloc,
        child: Scaffold(body: BotEditSheet(bot: editing)),
      ),
    );
  }

  testWidgets('precarga el nombre y muestra canal + identifier read-only', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(find.text('Editar bot'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Soporte'), findsOneWidget);
    // Canal como pill read-only (NO un TextField editable — I-B3 inmutable).
    expect(find.widgetWithText(AppPill, 'WhatsApp'), findsOneWidget);
    // Identifier read-only seleccionable.
    expect(find.text('5215512345678'), findsOneWidget);
    // Sólo el nombre es editable: un único TextField.
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('submit con nombre vacío no despacha', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.byKey(const Key('bot_edit.name')), '   ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('bot_edit.submit')));
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('submit con nombre nuevo → UpdateRequested(name)', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.enterText(
      find.byKey(const Key('bot_edit.name')),
      'Soporte Premium',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('bot_edit.submit')));

    verify(
      () => bloc.add(const BotDetailUpdateRequested(name: 'Soporte Premium')),
    ).called(1);
  });

  testWidgets('MutationFailed(422) muestra copy inline de nombre inválido', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        state: const BotDetailMutationFailed(_bot, BotsInvalidCreateFailure()),
      ),
    );
    await tester.pump();
    expect(find.textContaining('nombre'), findsWidgets);
  });

  testWidgets('MutationFailed(409) muestra copy de desactualizado', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(state: const BotDetailMutationFailed(_bot, BotsConflictFailure())),
    );
    await tester.pump();
    expect(find.textContaining('desactualizada'), findsOneWidget);
  });

  testWidgets('Mutating: el submit muestra loading', (tester) async {
    await tester.pumpWidget(host(state: const BotDetailMutating(_bot)));
    await tester.pump();
    // El botón sigue presente; el campo queda inhabilitado durante el PUT.
    expect(find.byKey(const Key('bot_edit.submit')), findsOneWidget);
  });

  testWidgets('éxito (Loaded tras submit) cierra el sheet', (tester) async {
    final ctrl = StreamController<BotDetailState>.broadcast();
    addTearDown(ctrl.close);
    when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));
    whenListen(bloc, ctrl.stream, initialState: const BotDetailLoaded(_bot));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<BotDetailBloc>.value(
          value: bloc,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BotEditSheet.openEdit(context, _bot),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Editar bot'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('bot_edit.name')), 'Nuevo');
    await tester.pump();
    await tester.tap(find.byKey(const Key('bot_edit.submit')));
    // El bloc procesa el PUT y vuelve a Loaded con el bot actualizado.
    ctrl.add(
      const BotDetailLoaded(
        Bot(
          id: 'b1',
          orgId: 'o1',
          templateId: 't1',
          name: 'Nuevo',
          channel: BotChannel.waUnofficial,
          identifier: '5215512345678',
          version: 4,
          paused: false,
          aiDisabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Editar bot'), findsNothing);
  });
}
