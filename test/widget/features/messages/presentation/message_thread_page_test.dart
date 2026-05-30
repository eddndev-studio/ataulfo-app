import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/domain/failures/messages_failure.dart';
import 'package:ataulfo/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:ataulfo/features/messages/presentation/pages/message_thread_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMessagesBloc extends MockBloc<MessagesEvent, MessagesState>
    implements MessagesBloc {}

Message msg({
  String externalId = 'e1',
  MessageDirection direction = MessageDirection.inbound,
  MessageKind kind = MessageKind.dm,
  String senderLid = 'alice',
  String type = 'text',
  String content = 'hola',
  String? quotedId,
  MessageStatus? status,
  int ts = 1700,
}) => Message(
  externalId: externalId,
  chatLid: 'lid-1',
  senderLid: senderLid,
  kind: kind,
  direction: direction,
  type: type,
  content: content,
  mediaRef: null,
  quotedId: quotedId,
  timestampMs: ts,
  status: status,
);

void main() {
  setUpAll(() => registerFallbackValue(const MessagesLoadRequested()));

  late _MockMessagesBloc bloc;

  setUp(() {
    bloc = _MockMessagesBloc();
    when(() => bloc.state).thenReturn(const MessagesInitial());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<MessagesBloc>.value(
      value: bloc,
      child: const Scaffold(body: MessageThreadPage()),
    ),
  );

  Alignment alignOf(WidgetTester tester, String ext) =>
      tester.widget<Align>(find.byKey(Key('message.$ext'))).alignment
          as Alignment;

  testWidgets('Loading muestra spinner', (tester) async {
    when(() => bloc.state).thenReturn(const MessagesLoading());
    await tester.pumpWidget(host());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Loaded alinea INBOUND a la izquierda y OUTBOUND a la derecha', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      MessagesLoaded(
        items: <Message>[
          msg(externalId: 'in', content: 'hola'),
          msg(
            externalId: 'out',
            direction: MessageDirection.outbound,
            content: 'qué tal',
            status: MessageStatus.read,
            ts: 1800,
          ),
        ],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    await tester.pumpWidget(host());

    expect(find.text('hola'), findsOneWidget);
    expect(find.text('qué tal'), findsOneWidget);
    expect(alignOf(tester, 'in'), Alignment.centerLeft);
    expect(alignOf(tester, 'out'), Alignment.centerRight);
  });

  group('OUTBOUND ticks de entrega', () {
    Future<void> pumpStatus(WidgetTester tester, MessageStatus s) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[
            msg(
              externalId: 'out',
              direction: MessageDirection.outbound,
              status: s,
            ),
          ],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());
    }

    testWidgets('SENT → una palomita (done) gris', (tester) async {
      await pumpStatus(tester, MessageStatus.sent);
      expect(find.byIcon(Icons.done_all), findsNothing);
      expect(tester.widget<Icon>(find.byIcon(Icons.done)).color, AppTokens.text2);
    });

    testWidgets('DELIVERED → doble palomita (done_all) gris', (tester) async {
      await pumpStatus(tester, MessageStatus.delivered);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.done_all)).color,
        AppTokens.text2,
      );
    });

    testWidgets('READ → doble palomita (done_all) verde de sección', (
      tester,
    ) async {
      await pumpStatus(tester, MessageStatus.read);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.done_all)).color,
        AppTokens.chatAccent,
      );
    });

    testWidgets('FAILED → ícono de error rojo', (tester) async {
      await pumpStatus(tester, MessageStatus.failed);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.error_outline)).color,
        AppTokens.danger,
      );
    });

    testWidgets('el tick conserva la etiqueta de texto para a11y', (
      tester,
    ) async {
      await pumpStatus(tester, MessageStatus.read);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.done_all)).semanticLabel,
        'Leído',
      );
    });

    testWidgets('INBOUND no muestra ningún tick', (tester) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[msg(externalId: 'in')],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());
      expect(find.byIcon(Icons.done), findsNothing);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });
  });

  testWidgets('INBOUND de grupo muestra el autor (senderLid)', (tester) async {
    when(() => bloc.state).thenReturn(
      MessagesLoaded(
        items: <Message>[
          msg(externalId: 'g', kind: MessageKind.group, senderLid: 'bob'),
        ],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('bob'), findsOneWidget);
  });

  group('respuestas citadas (quoted replies)', () {
    testWidgets('reply resuelto muestra el bloque de cita con el preview', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[
            msg(externalId: 'orig', senderLid: 'bob', content: 'el original'),
            msg(
              externalId: 'reply',
              direction: MessageDirection.outbound,
              content: 'mi respuesta',
              quotedId: 'orig',
              ts: 1800,
            ),
          ],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());

      final quote = find.byKey(const Key('message.quoted.reply'));
      expect(quote, findsOneWidget);
      // El preview del citado vive DENTRO del bloque de cita de 'reply'.
      expect(
        find.descendant(of: quote, matching: find.text('el original')),
        findsOneWidget,
      );
      // La barra de la cita usa el verde de sección.
      final bar = tester.widget<Container>(
        find.byKey(const Key('message.quoted.reply.bar')),
      );
      expect(bar.color, AppTokens.chatAccent);
    });

    testWidgets('reply con citado fuera de ventana → fallback', (tester) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[
            msg(externalId: 'reply', content: 'respondo', quotedId: 'ausente'),
          ],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());

      final quote = find.byKey(const Key('message.quoted.reply'));
      expect(quote, findsOneWidget);
      expect(
        find.descendant(
          of: quote,
          matching: find.text('Mensaje original no disponible'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('mensaje sin quotedId no muestra bloque de cita', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[msg(externalId: 'plain')],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('message.quoted.plain')), findsNothing);
    });
  });

  group('reacciones (agregación en cliente)', () {
    testWidgets('la reacción se dobla sobre el target y no es una burbuja', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[
            msg(externalId: 'm1', content: 'qué buena foto'),
            msg(
              externalId: 'r1',
              type: 'reaction',
              content: '👍',
              quotedId: 'm1',
              ts: 1900,
            ),
          ],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());

      // El target conserva su burbuja; la reacción NO tiene burbuja propia.
      expect(find.byKey(const Key('message.m1')), findsOneWidget);
      expect(find.byKey(const Key('message.r1')), findsNothing);
      // La reacción se muestra como pill sobre el target.
      final pills = find.byKey(const Key('message.reactions.m1'));
      expect(pills, findsOneWidget);
      expect(find.descendant(of: pills, matching: find.text('👍')), findsOneWidget);
    });

    testWidgets('mensaje sin reacciones no muestra pills', (tester) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[msg(externalId: 'm1')],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('message.reactions.m1')), findsNothing);
    });
  });

  testWidgets('tipo no-texto se pinta como placeholder [tipo]', (tester) async {
    when(() => bloc.state).thenReturn(
      MessagesLoaded(
        items: <Message>[msg(externalId: 'm', type: 'image', content: '')],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('[image]'), findsOneWidget);
  });

  testWidgets('Loaded vacío muestra empty state', (tester) async {
    when(() => bloc.state).thenReturn(
      const MessagesLoaded(
        items: <Message>[],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('messages.empty')), findsOneWidget);
  });

  testWidgets('isLoadingOlder muestra el indicador de cargar más', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      MessagesLoaded(
        items: <Message>[msg()],
        prevCursor: '100:x',
        isLoadingOlder: true,
      ),
    );
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('messages.older_loading')), findsOneWidget);
  });

  testWidgets('Failed NotFound → copy específico', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const MessagesFailed(MessagesNotFoundFailure()));
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('messages.error.not_found')), findsOneWidget);
  });

  testWidgets('Failed genérico → mensaje + Reintentar dispara Load', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const MessagesFailed(MessagesNetworkFailure()));
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('messages.error.generic')), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();
    verify(() => bloc.add(const MessagesLoadRequested())).called(1);
  });

  testWidgets(
    'scroll hasta el tope (hay más viejos) dispara MessagesOlderRequested',
    (tester) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[
            for (var i = 0; i < 40; i++) msg(externalId: 'm$i', ts: 1000 + i),
          ],
          prevCursor: '999:m0',
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());

      final pos = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pump();

      verify(
        () => bloc.add(const MessagesOlderRequested()),
      ).called(greaterThanOrEqualTo(1));
    },
  );
}
