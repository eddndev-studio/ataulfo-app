import 'dart:async';
import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
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

class _MockFilePicker extends Mock implements MediaFilePicker {}

class _MockMediaRepo extends Mock implements MediaRepository {}

Message msg({
  String externalId = 'e1',
  MessageDirection direction = MessageDirection.inbound,
  MessageKind kind = MessageKind.dm,
  String senderLid = 'alice',
  String type = 'text',
  String content = 'hola',
  String? quotedId,
  String? mediaUrl,
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
  mediaUrl: mediaUrl,
  quotedId: quotedId,
  timestampMs: ts,
  status: status,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const MessagesLoadRequested());
    registerFallbackValue(Uint8List(0));
  });

  late _MockMessagesBloc bloc;

  setUp(() {
    bloc = _MockMessagesBloc();
    when(() => bloc.state).thenReturn(const MessagesInitial());
    when(
      () => bloc.reactFailures,
    ).thenAnswer((_) => const Stream<void>.empty());
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

  testWidgets('un fallo de reacción se anuncia con SnackBar', (tester) async {
    // La reacción se materializa por eco SSE; el único feedback posible del
    // fallo es el side-channel del bloc → SnackBar.
    final failures = StreamController<void>.broadcast();
    addTearDown(failures.close);
    when(() => bloc.reactFailures).thenAnswer((_) => failures.stream);
    when(() => bloc.state).thenReturn(
      const MessagesLoaded(
        items: <Message>[],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );

    await tester.pumpWidget(host());
    failures.add(null);
    await tester.pump(); // entrega del stream
    await tester.pump(); // frame del SnackBar

    expect(find.text('No se pudo enviar la reacción'), findsOneWidget);
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
      expect(
        tester.widget<Icon>(find.byIcon(Icons.done)).color,
        AppTokens.text2,
      );
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
      expect(
        find.descendant(of: pills, matching: find.text('👍')),
        findsOneWidget,
      );
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

  testWidgets('tipo no catalogado cae a placeholder [tipo]', (tester) async {
    when(() => bloc.state).thenReturn(
      MessagesLoaded(
        items: <Message>[msg(externalId: 'm', type: 'location', content: '')],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('[location]'), findsOneWidget);
  });

  group('multimedia (render por tipo via mediaUrl)', () {
    Future<void> pumpMsg(WidgetTester tester, Message m) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[m],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());
    }

    testWidgets('imagen con mediaUrl renderiza un Image', (tester) async {
      await pumpMsg(
        tester,
        msg(
          externalId: 'img',
          type: 'image',
          content: '',
          mediaUrl: 'https://cdn/x.jpg',
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('imagen sin mediaUrl → placeholder de tipo (sin Image)', (
      tester,
    ) async {
      await pumpMsg(tester, msg(externalId: 'img', type: 'image', content: ''));
      expect(find.byType(Image), findsNothing);
      expect(find.text('Imagen'), findsOneWidget);
    });

    testWidgets('imagen con caption muestra el texto', (tester) async {
      await pumpMsg(
        tester,
        msg(
          externalId: 'img',
          type: 'image',
          content: 'mira esto',
          mediaUrl: 'https://cdn/x.jpg',
        ),
      );
      expect(find.text('mira esto'), findsOneWidget);
    });

    testWidgets('video → tarjeta de tipo (ícono + etiqueta)', (tester) async {
      await pumpMsg(
        tester,
        msg(
          externalId: 'vid',
          type: 'video',
          content: '',
          mediaUrl: 'https://cdn/x.mp4',
        ),
      );
      expect(find.text('Video'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      // v1: el video no se reproduce inline (sin dep de player).
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('audio → tarjeta "Audio"', (tester) async {
      await pumpMsg(tester, msg(externalId: 'aud', type: 'audio', content: ''));
      expect(find.text('Audio'), findsOneWidget);
    });

    testWidgets('documento → tarjeta "Documento"', (tester) async {
      await pumpMsg(
        tester,
        msg(externalId: 'doc', type: 'document', content: ''),
      );
      expect(find.text('Documento'), findsOneWidget);
    });
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

      // El composer añade su propio Scrollable (TextField multilínea); la lista
      // del hilo es la primera en el árbol.
      final pos = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pump();

      verify(
        () => bloc.add(const MessagesOlderRequested()),
      ).called(greaterThanOrEqualTo(1));
    },
  );

  group('reaccionar (long-press)', () {
    testWidgets('long-press abre el picker; elegir emoji dispatcha react', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[msg(externalId: 'm1', content: 'hola')],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());
      await tester.longPress(find.text('hola'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reaction.pick.m1.👍')), findsOneWidget);
      await tester.tap(find.byKey(const Key('reaction.pick.m1.👍')));
      await tester.pumpAndSettle();
      verify(
        () => bloc.add(
          const MessagesReactRequested(messageId: 'm1', emoji: '👍'),
        ),
      ).called(1);
    });
  });

  group('composer (envío)', () {
    const loadedEmpty = MessagesLoaded(
      items: <Message>[],
      prevCursor: null,
      isLoadingOlder: false,
    );

    testWidgets('Loaded muestra el composer (input + enviar)', (tester) async {
      when(() => bloc.state).thenReturn(loadedEmpty);
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('composer.input')), findsOneWidget);
      expect(find.byKey(const Key('composer.send')), findsOneWidget);
    });

    testWidgets('Loading y Failed ocultan el composer', (tester) async {
      when(() => bloc.state).thenReturn(const MessagesLoading());
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('composer.input')), findsNothing);

      when(
        () => bloc.state,
      ).thenReturn(const MessagesFailed(MessagesNetworkFailure()));
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('composer.input')), findsNothing);
    });

    testWidgets('escribir + enviar dispatcha MessagesSendRequested y limpia', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(loadedEmpty);
      await tester.pumpWidget(host());
      await tester.enterText(
        find.byKey(const Key('composer.input')),
        'hola mundo',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('composer.send')));
      await tester.pump();
      verify(
        () => bloc.add(
          const MessagesSendRequested(type: 'text', content: 'hola mundo'),
        ),
      ).called(1);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('composer.input')))
            .controller!
            .text,
        '',
      );
    });

    testWidgets('enviar con sólo espacios no dispatcha', (tester) async {
      when(() => bloc.state).thenReturn(loadedEmpty);
      await tester.pumpWidget(host());
      await tester.enterText(find.byKey(const Key('composer.input')), '   ');
      await tester.pump();
      await tester.tap(find.byKey(const Key('composer.send')));
      await tester.pump();
      verifyNever(() => bloc.add(any(that: isA<MessagesSendRequested>())));
    });

    testWidgets('burbuja pendiente (enviando) se pinta con ícono de reloj', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[msg(externalId: 'm1')],
          prevCursor: null,
          isLoadingOlder: false,
          pending: const <PendingSend>[
            PendingSend(
              clientToken: 'ct-1',
              type: 'text',
              content: 'pendiente',
            ),
          ],
        ),
      );
      await tester.pumpWidget(host());
      final bubble = find.byKey(const Key('message.pending.ct-1'));
      expect(bubble, findsOneWidget);
      expect(
        find.descendant(of: bubble, matching: find.text('pendiente')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bubble, matching: find.byIcon(Icons.schedule)),
        findsOneWidget,
      );
    });

    testWidgets('pending vacío + items vacíos NO muestra el empty state', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const MessagesLoaded(
          items: <Message>[],
          prevCursor: null,
          isLoadingOlder: false,
          pending: <PendingSend>[
            PendingSend(
              clientToken: 'ct-1',
              type: 'text',
              content: 'sólo esto',
            ),
          ],
        ),
      );
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('messages.empty')), findsNothing);
      expect(find.byKey(const Key('message.pending.ct-1')), findsOneWidget);
    });

    testWidgets('burbuja fallida ofrece reintentar y descartar', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const MessagesLoaded(
          items: <Message>[],
          prevCursor: null,
          isLoadingOlder: false,
          pending: <PendingSend>[
            PendingSend(
              clientToken: 'ct-9',
              type: 'text',
              content: 'falló esto',
              failure: MessagesNotConnectedFailure(),
            ),
          ],
        ),
      );
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('message.pending.ct-9.retry')));
      await tester.pump();
      verify(
        () => bloc.add(const MessagesSendRetryRequested('ct-9')),
      ).called(1);
      await tester.tap(find.byKey(const Key('message.pending.ct-9.discard')));
      await tester.pump();
      verify(() => bloc.add(const MessagesSendDiscarded('ct-9'))).called(1);
    });
  });

  group('adjuntar imagen', () {
    late _MockFilePicker picker;
    late _MockMediaRepo mediaRepo;

    setUp(() {
      picker = _MockFilePicker();
      mediaRepo = _MockMediaRepo();
      when(() => bloc.state).thenReturn(
        const MessagesLoaded(
          items: <Message>[],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
    });

    Widget hostMedia() => MaterialApp(
      theme: AppDesignTheme.dark(),
      home: MultiRepositoryProvider(
        providers: <RepositoryProvider<dynamic>>[
          RepositoryProvider<MediaFilePicker>.value(value: picker),
          RepositoryProvider<MediaRepository>.value(value: mediaRepo),
        ],
        child: BlocProvider<MessagesBloc>.value(
          value: bloc,
          child: const Scaffold(body: MessageThreadPage()),
        ),
      ),
    );

    testWidgets('pick + upload → envía type:image con ref y caption', (
      tester,
    ) async {
      when(() => picker.pick()).thenAnswer(
        (_) async => PickedMedia(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          filename: 'foto.jpg',
        ),
      );
      when(
        () => mediaRepo.upload(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      ).thenAnswer(
        (_) async => const UploadedMedia(ref: 'ref-abc', previewUrl: null),
      );
      await tester.pumpWidget(hostMedia());
      await tester.enterText(
        find.byKey(const Key('composer.input')),
        'mira esto',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('composer.attach')));
      await tester.pumpAndSettle();
      verify(
        () => bloc.add(
          const MessagesSendRequested(
            type: 'image',
            content: 'mira esto',
            mediaRef: 'ref-abc',
          ),
        ),
      ).called(1);
    });

    testWidgets('cancelar el picker no sube ni envía', (tester) async {
      when(() => picker.pick()).thenAnswer((_) async => null);
      await tester.pumpWidget(hostMedia());
      await tester.tap(find.byKey(const Key('composer.attach')));
      await tester.pumpAndSettle();
      verifyNever(
        () => mediaRepo.upload(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      );
      verifyNever(() => bloc.add(any(that: isA<MessagesSendRequested>())));
    });
  });
}
