import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_detail_bloc.dart';
import 'package:ataulfo/features/bots/presentation/widgets/bot_clone_sheet.dart';
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
  identifier: null,
  version: 3,
  paused: false,
  aiDisabled: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const BotDetailCloneRequested('x'));
  });

  late _MockBloc bloc;
  setUp(() => bloc = _MockBloc());

  Widget host({BotDetailState? state}) {
    final s = state ?? const BotDetailLoaded(_bot);
    when(() => bloc.state).thenReturn(s);
    whenListen(bloc, const Stream<BotDetailState>.empty(), initialState: s);
    return MaterialApp(
      theme: AppDesignTheme.dark(),
      home: BlocProvider<BotDetailBloc>.value(
        value: bloc,
        child: Scaffold(
          body: BotCloneSheet(onCloned: (_) {}),
        ),
      ),
    );
  }

  testWidgets('submit vacío no despacha', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('bot_clone.submit')));
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('submit con nombre → BotDetailCloneRequested(name)', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.enterText(
      find.byKey(const Key('bot_clone.name')),
      'Soporte (copia)',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('bot_clone.submit')));

    verify(
      () => bloc.add(const BotDetailCloneRequested('Soporte (copia)')),
    ).called(1);
  });

  testWidgets('MutationFailed(invalid) muestra copy del nombre', (
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

  testWidgets('CloneSucceeded → cierra el sheet y llama onCloned(newId)', (
    tester,
  ) async {
    final ctrl = StreamController<BotDetailState>.broadcast();
    addTearDown(ctrl.close);
    String? clonedId;
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
                onPressed: () => BotCloneSheet.open(
                  context,
                  onCloned: (id) => clonedId = id,
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
    expect(find.byKey(const Key('bot_clone.submit')), findsOneWidget);

    ctrl.add(const BotDetailCloneSucceeded('b2'));
    await tester.pumpAndSettle();

    // El sheet se cerró y el callback recibió el id del clon.
    expect(find.byKey(const Key('bot_clone.submit')), findsNothing);
    expect(clonedId, 'b2');
  });
}
