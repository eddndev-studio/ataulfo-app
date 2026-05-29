import 'package:ataulfo/core/design/app_design_theme.dart';
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
  quotedId: null,
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

  testWidgets('OUTBOUND con status READ muestra "Leído"', (tester) async {
    when(() => bloc.state).thenReturn(
      MessagesLoaded(
        items: <Message>[
          msg(
            externalId: 'out',
            direction: MessageDirection.outbound,
            status: MessageStatus.read,
          ),
        ],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('Leído'), findsOneWidget);
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
