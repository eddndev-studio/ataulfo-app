import 'dart:async';
import 'dart:convert';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_chat_composer.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/media/data/repositories/noop_camera_capture.dart';
import 'package:ataulfo/features/media/data/repositories/noop_device_gallery.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/repositories/camera_capture.dart';
import 'package:ataulfo/features/media/domain/repositories/device_gallery_port.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/messages/data/cache/message_media_cache.dart';
import 'package:ataulfo/features/messages/data/media/noop_audio_recorder.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/core/audio/audio_recorder.dart';
import 'package:ataulfo/features/messages/domain/failures/messages_failure.dart';
import 'package:ataulfo/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:ataulfo/features/messages/domain/repositories/media_opener.dart';
import 'package:ataulfo/features/messages/presentation/widgets/message_media.dart';
import 'package:ataulfo/features/messages/presentation/widgets/video_playback.dart';
import 'package:ataulfo/features/messages/presentation/bloc/thread_audio_cubit.dart';
import 'package:ataulfo/features/messages/presentation/pages/message_thread_page.dart';
import 'package:ataulfo/features/monitor/data/datasources/monitor_activity_datasource.dart';
import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/monitor/presentation/cubit/monitor_live_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_message_media_cache.dart';

class _MockMessagesBloc extends MockBloc<MessagesEvent, MessagesState>
    implements MessagesBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockFilePicker extends Mock implements MediaFilePicker {}

class _MockMediaRepo extends Mock implements MediaRepository {}

class _MockThreadAudioCubit extends MockCubit<ThreadAudioState>
    implements ThreadAudioCubit {}

class _MockMediaOpener extends Mock implements MediaOpener {}

/// Fake de reproducción de video: registra las URLs abiertas sin tocar el
/// plugin de video (BuildContext como argumento no se presta a un mock).
class _FakeVideoPlayback implements VideoPlayback {
  final List<String> calls = <String>[];

  @override
  Future<void> open(BuildContext context, {required String url}) async {
    calls.add(url);
  }
}

class _FakeMonitorDs implements MonitorActivityDatasource {
  @override
  Stream<MonitorEvent> activity(String botId, String chatLid) =>
      const Stream<MonitorEvent>.empty();
}

Message msg({
  String externalId = 'e1',
  MessageDirection direction = MessageDirection.inbound,
  MessageKind kind = MessageKind.dm,
  String senderLid = 'alice',
  String type = 'text',
  String content = 'hola',
  String? quotedId,
  String? mediaRef,
  String? mediaUrl,
  MessageStatus? status,
  int ts = 1700,
  int? editedAtMs,
  int? revokedAtMs,
}) => Message(
  externalId: externalId,
  chatLid: 'lid-1',
  senderLid: senderLid,
  kind: kind,
  direction: direction,
  type: type,
  content: content,
  mediaRef: mediaRef,
  mediaUrl: mediaUrl,
  quotedId: quotedId,
  timestampMs: ts,
  status: status,
  editedAtMs: editedAtMs,
  revokedAtMs: revokedAtMs,
);

/// 1x1 PNG válido: que Image.memory decodifique sin caer al errorBuilder.
final _pngBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  ),
);

/// PNG 4×2 (relación de aspecto 2.0): una imagen "ancha" para verificar que el
/// hilo la pinta a su relación real y no como recorte cuadrado.
final _widePngBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAEklEQVR42mMIqDjxHxkzoAsAAFK1FHkNntrXAAAAAElFTkSuQmCC',
  ),
);

/// PNG 2×4 (relación de aspecto 0.5): una imagen "alta".
final _tallPngBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAAECAYAAACk7+45AAAAEUlEQVR42mMIqDjxH4QZcDMAZy8UeZKbYFMAAAAASUVORK5CYII=',
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const MessagesLoadRequested());
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(Duration.zero);
  });

  late _MockMessagesBloc bloc;
  late _MockThreadAudioCubit audio;
  late _MockMediaOpener opener;
  late _FakeVideoPlayback videoPlayback;
  late _MockAuthBloc authBloc;

  setUp(() {
    bloc = _MockMessagesBloc();
    audio = _MockThreadAudioCubit();
    opener = _MockMediaOpener();
    videoPlayback = _FakeVideoPlayback();
    authBloc = _MockAuthBloc();
    when(() => bloc.state).thenReturn(const MessagesInitial());
    when(
      () => bloc.reactFailures,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(
      () => bloc.correctionFailures,
    ).thenAnswer((_) => const Stream<MessagesFailure>.empty());
    when(() => audio.state).thenReturn(const ThreadAudioState());
    // Por defecto sin sesión: el drill-through (ADMIN+) queda oculto y la
    // reacción funciona igual; los tests que lo prueban fijan un estado ADMIN.
    when(() => authBloc.state).thenReturn(const AuthInitial());
  });

  Widget host({MessageMediaCache? mediaCache}) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: RepositoryProvider<MessageMediaCache>.value(
      value: mediaCache ?? fakeMessageMediaCache(),
      child: RepositoryProvider<AudioRecorder>.value(
        value: const NoopAudioRecorder(),
        child: RepositoryProvider<MediaOpener>.value(
          value: opener,
          child: RepositoryProvider<VideoPlayback>.value(
            value: videoPlayback,
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<MessagesBloc>.value(value: bloc),
                BlocProvider<ThreadAudioCubit>.value(value: audio),
                BlocProvider<AuthBloc>.value(value: authBloc),
                // El footer de actividad live lo lee del scope; inerte aquí (sin
                // observar) ⇒ no pinta nada.
                BlocProvider<MonitorLiveCubit>(
                  create: (_) => MonitorLiveCubit(_FakeMonitorDs()),
                ),
              ],
              child: const Scaffold(body: MessageThreadPage()),
            ),
          ),
        ),
      ),
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

    testWidgets(
      'cita de una imagen muestra "Foto" con ícono (no texto crudo)',
      (tester) async {
        when(() => bloc.state).thenReturn(
          MessagesLoaded(
            items: <Message>[
              msg(
                externalId: 'origimg',
                senderLid: 'bob',
                type: 'image',
                content: '',
                mediaRef: 'r',
              ),
              msg(
                externalId: 'reply',
                direction: MessageDirection.outbound,
                content: 'mira',
                quotedId: 'origimg',
                ts: 1800,
              ),
            ],
            prevCursor: null,
            isLoadingOlder: false,
          ),
        );
        await tester.pumpWidget(host());
        final quote = find.byKey(const Key('message.quoted.reply'));
        expect(
          find.descendant(of: quote, matching: find.text('Foto')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: quote,
            matching: find.byIcon(Icons.image_outlined),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('cita de una nota de voz muestra "Nota de voz"', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[
            msg(
              externalId: 'origv',
              senderLid: 'bob',
              type: 'ptt',
              content: '',
            ),
            msg(
              externalId: 'reply',
              direction: MessageDirection.outbound,
              content: 'ok',
              quotedId: 'origv',
              ts: 1800,
            ),
          ],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());
      final quote = find.byKey(const Key('message.quoted.reply'));
      expect(
        find.descendant(of: quote, matching: find.text('Nota de voz')),
        findsOneWidget,
      );
    });

    testWidgets('tocar una cita resuelta salta y resalta el mensaje original', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[
            msg(externalId: 'orig', senderLid: 'bob', content: 'el original'),
            msg(
              externalId: 'reply',
              direction: MessageDirection.outbound,
              content: 'respondo',
              quotedId: 'orig',
              ts: 1800,
            ),
          ],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('message.quoted.reply')));
      await tester.pumpAndSettle(); // ensureVisible + resalta el original
      final deco =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const Key('message.orig.hl')),
                  )
                  .decoration
              as BoxDecoration;
      expect(deco.color, AppTokens.chatAccent.withValues(alpha: 0.15));
      // Drena el temporizador de limpieza del destello (no dejar timers vivos).
      await tester.pump(const Duration(milliseconds: 1500));
    });

    testWidgets('la cita a un citado fuera de ventana no es interactiva', (
      tester,
    ) async {
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
      // La cita fallback no lleva el gesto de salto (no es tocable).
      expect(find.byKey(const Key('message.quoted.reply.tap')), findsNothing);
      expect(find.byKey(const Key('message.quoted.reply')), findsOneWidget);
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
        items: <Message>[
          msg(externalId: 'm', type: 'carta_astral', content: ''),
        ],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('[carta_astral]'), findsOneWidget);
  });

  testWidgets('envío optimista de nota de voz se rotula [nota de voz]', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const MessagesLoaded(
        items: <Message>[],
        prevCursor: null,
        isLoadingOlder: false,
        pending: <PendingSend>[
          PendingSend(
            clientToken: 'ct-voz',
            type: 'ptt',
            content: '',
            mediaRef: 'ref-voz',
          ),
        ],
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('[nota de voz]'), findsOneWidget);
    expect(find.text('[imagen]'), findsNothing);
  });

  group('multimedia (render por tipo)', () {
    final pngBytes = _pngBytes;

    Future<void> pumpMsg(
      WidgetTester tester,
      Message m, {
      MessageMediaCache? cache,
    }) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[m],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host(mediaCache: cache));
    }

    testWidgets('revocado oculta el contenido y muestra el marcador', (
      tester,
    ) async {
      await pumpMsg(
        tester,
        msg(
          externalId: 'rev',
          direction: MessageDirection.outbound,
          content: 'texto que ya no debe verse',
          revokedAtMs: 999,
        ),
      );
      expect(find.text('Se eliminó este mensaje'), findsOneWidget);
      expect(find.text('texto que ya no debe verse'), findsNothing);
    });

    testWidgets('editado muestra el marcador junto a la hora', (tester) async {
      await pumpMsg(
        tester,
        msg(
          externalId: 'ed',
          direction: MessageDirection.outbound,
          content: 'precio corregido',
          editedAtMs: 999,
        ),
      );
      expect(find.text('precio corregido'), findsOneWidget);
      expect(find.text('editada'), findsOneWidget);
    });

    testWidgets('encuesta pinta pregunta y opciones desde el JSON', (
      tester,
    ) async {
      await pumpMsg(
        tester,
        msg(
          externalId: 'poll',
          direction: MessageDirection.outbound,
          type: 'poll',
          content:
              '{"question":"¿Qué día te queda?","options":["Lunes","Martes"],"multiple":false}',
        ),
      );
      expect(find.text('¿Qué día te queda?'), findsOneWidget);
      expect(find.text('Lunes'), findsOneWidget);
      expect(find.text('Martes'), findsOneWidget);
    });

    testWidgets('ubicación pinta tarjeta tipada + contenido', (tester) async {
      await pumpMsg(
        tester,
        msg(externalId: 'loc', type: 'location', content: 'Sucursal — Av. 1'),
      );
      expect(find.text('Ubicación'), findsOneWidget);
      expect(find.text('Sucursal — Av. 1'), findsOneWidget);
    });

    testWidgets('contacto pinta tarjeta tipada + contenido', (tester) async {
      await pumpMsg(
        tester,
        msg(externalId: 'con', type: 'contact', content: 'Asesor Luis'),
      );
      expect(find.text('Contacto'), findsOneWidget);
      expect(find.text('Asesor Luis'), findsOneWidget);
    });

    testWidgets('imagen con bytes en caché renderiza un Image', (tester) async {
      await pumpMsg(
        tester,
        msg(
          externalId: 'img',
          type: 'image',
          content: '',
          mediaRef: 'ref-x',
          mediaUrl: 'https://cdn/x.jpg',
        ),
        cache: fakeMessageMediaCache(downloadResult: pngBytes),
      );
      await tester.pumpAndSettle(); // resuelve la carga async + el decode
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('imagen sin mediaRef → placeholder de tipo (sin Image)', (
      tester,
    ) async {
      await pumpMsg(tester, msg(externalId: 'img', type: 'image', content: ''));
      expect(find.byType(Image), findsNothing);
      expect(find.text('Imagen'), findsOneWidget);
    });

    testWidgets('ptt sin URL firmada → tarjeta "Nota de voz"', (tester) async {
      await pumpMsg(tester, msg(externalId: 'v', type: 'ptt', content: ''));
      expect(find.text('Nota de voz'), findsOneWidget);
      expect(find.text('Audio'), findsNothing);
    });

    testWidgets(
      'imagen con mediaRef pero sin bytes (offline) → no disponible',
      (tester) async {
        await pumpMsg(
          tester,
          // Sin mediaUrl ni caché: la resolución da null.
          msg(externalId: 'img', type: 'image', content: '', mediaRef: 'ref-x'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsNothing);
        expect(find.text('Imagen no disponible'), findsOneWidget);
      },
    );

    testWidgets('imagen con caption muestra el texto', (tester) async {
      await pumpMsg(
        tester,
        msg(
          externalId: 'img',
          type: 'image',
          content: 'mira esto',
          mediaRef: 'ref-x',
          mediaUrl: 'https://cdn/x.jpg',
        ),
        cache: fakeMessageMediaCache(downloadResult: pngBytes),
      );
      await tester.pump();
      expect(find.text('mira esto'), findsOneWidget);
    });

    // Arnés que reconstruye MessageMediaContent con un mensaje cambiante (mismo
    // slot ⇒ didUpdateWidget en _MessageImage), con la caché REAL (su lógica
    // url-null→null decide). Valida la corrección del fix de S9.
    Future<void> pumpContent(
      WidgetTester tester, {
      required MessageMediaCache cache,
      required ValueListenable<Message> message,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: RepositoryProvider<MessageMediaCache>.value(
            value: cache,
            child: Scaffold(
              body: ValueListenableBuilder<Message>(
                valueListenable: message,
                builder: (_, m, _) => MessageMediaContent(message: m),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'imagen: la firma viva que llega tras "no disponible" dispara la descarga',
      (tester) async {
        final cache = fakeMessageMediaCache(downloadResult: pngBytes);
        final m = ValueNotifier<Message>(
          msg(externalId: 'i9', type: 'image', content: '', mediaRef: 'ref-i9'),
        );
        addTearDown(m.dispose);

        await pumpContent(tester, cache: cache, message: m);
        await tester.pumpAndSettle();
        // Sin firma viva la caché no tiene de dónde bajar → no disponible.
        expect(find.text('Imagen no disponible'), findsOneWidget);
        expect(find.byType(Image), findsNothing);

        // Llega la firma (reconexión): el mismo slot reintenta y descarga.
        m.value = msg(
          externalId: 'i9',
          type: 'image',
          content: '',
          mediaRef: 'ref-i9',
          mediaUrl: 'https://cdn/i9.jpg',
        );
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
      },
    );

    testWidgets('imagen: reciclar el slot a otro ref descarta la imagen vieja', (
      tester,
    ) async {
      final cache = fakeMessageMediaCache(downloadResult: pngBytes);
      final m = ValueNotifier<Message>(
        msg(
          externalId: 'a',
          type: 'image',
          content: '',
          mediaRef: 'ref-a',
          mediaUrl: 'https://cdn/a.jpg',
        ),
      );
      addTearDown(m.dispose);

      await pumpContent(tester, cache: cache, message: m);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget); // ref-a resuelve bytes

      // El slot se recicla a otro ref SIN firma viva: no debe seguir pintando A.
      m.value = msg(
        externalId: 'b',
        type: 'image',
        content: '',
        mediaRef: 'ref-b',
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Imagen no disponible'), findsOneWidget);
    });

    testWidgets(
      'video con URL → burbuja con play, reproduce dentro de la app',
      (tester) async {
        await pumpMsg(
          tester,
          msg(
            externalId: 'vid',
            type: 'video',
            content: '',
            mediaUrl: 'https://cdn/x.mp4',
          ),
        );
        expect(find.byKey(const Key('message.video.vid')), findsOneWidget);
        expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
        await tester.tap(find.byKey(const Key('message.video.vid')));
        await tester.pump();
        expect(videoPlayback.calls, <String>['https://cdn/x.mp4']);
      },
    );

    testWidgets('video sin URL firmada → tarjeta de tipo (no reproducible)', (
      tester,
    ) async {
      await pumpMsg(
        tester,
        msg(externalId: 'vid2', type: 'video', content: ''),
      );
      expect(find.text('Video'), findsOneWidget);
      expect(find.byKey(const Key('message.video.vid2')), findsNothing);
    });

    testWidgets('audio → tarjeta "Audio"', (tester) async {
      await pumpMsg(tester, msg(externalId: 'aud', type: 'audio', content: ''));
      expect(find.text('Audio'), findsOneWidget);
    });

    testWidgets('documento sin nombre → "Documento"', (tester) async {
      await pumpMsg(
        tester,
        msg(externalId: 'doc', type: 'document', content: ''),
      );
      expect(find.text('Documento'), findsOneWidget);
    });

    AspectRatio imageAspectOf(WidgetTester tester) =>
        tester.widget<AspectRatio>(
          find.descendant(
            of: find.byType(MessageMediaContent),
            matching: find.byType(AspectRatio),
          ),
        );

    testWidgets('imagen ancha se pinta a su relación de aspecto (~2.0)', (
      tester,
    ) async {
      await pumpMsg(
        tester,
        msg(
          externalId: 'imgw',
          type: 'image',
          content: '',
          mediaRef: 'ref-w',
          mediaUrl: 'https://cdn/w.png',
        ),
        cache: fakeMessageMediaCache(downloadResult: _widePngBytes),
      );
      await tester.pumpAndSettle();
      expect(imageAspectOf(tester).aspectRatio, closeTo(2.0, 0.01));
    });

    testWidgets('imagen alta se pinta a su relación de aspecto (~0.5)', (
      tester,
    ) async {
      await pumpMsg(
        tester,
        msg(
          externalId: 'imgt',
          type: 'image',
          content: '',
          mediaRef: 'ref-t',
          mediaUrl: 'https://cdn/t.png',
        ),
        cache: fakeMessageMediaCache(downloadResult: _tallPngBytes),
      );
      await tester.pumpAndSettle();
      expect(imageAspectOf(tester).aspectRatio, closeTo(0.5, 0.01));
    });

    testWidgets(
      'imagen a relación de aspecto sigue abriendo el visor al tocar',
      (tester) async {
        await pumpMsg(
          tester,
          msg(
            externalId: 'imgv',
            type: 'image',
            content: '',
            mediaRef: 'ref-v',
            mediaUrl: 'https://cdn/v.png',
          ),
          cache: fakeMessageMediaCache(downloadResult: _widePngBytes),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('message.image.imgv')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('media_viewer')), findsOneWidget);
      },
    );

    testWidgets('documento con nombre lo muestra y es tocable (abre)', (
      tester,
    ) async {
      when(() => opener.open(url: any(named: 'url'))).thenAnswer((_) async {});
      await pumpMsg(
        tester,
        msg(
          externalId: 'doc1',
          type: 'document',
          content: 'factura.pdf',
          mediaUrl: 'https://cdn/factura.pdf',
        ),
      );
      await tester.pump();
      // El nombre se muestra UNA vez (en la tarjeta), sin duplicarse debajo.
      expect(find.text('factura.pdf'), findsOneWidget);
      await tester.tap(find.byKey(const Key('message.doc.doc1')));
      await tester.pump();
      verify(() => opener.open(url: 'https://cdn/factura.pdf')).called(1);
    });

    testWidgets('documento sin URL muestra el nombre pero no es tocable', (
      tester,
    ) async {
      await pumpMsg(
        tester,
        msg(externalId: 'doc3', type: 'document', content: 'informe.docx'),
      );
      await tester.pump();
      expect(find.text('informe.docx'), findsOneWidget);
      expect(find.byKey(const Key('message.doc.doc3')), findsNothing);
    });

    testWidgets(
      'sticker con bytes: cuadro natural (scaleDown) de 140, sin recorte',
      (tester) async {
        final cache = fakeMessageMediaCache(downloadResult: pngBytes);
        final m = ValueNotifier<Message>(
          msg(
            externalId: 's1',
            type: 'sticker',
            content: '',
            mediaRef: 'ref-s1',
            mediaUrl: 'https://cdn/s1.webp',
          ),
        );
        addTearDown(m.dispose);
        await pumpContent(tester, cache: cache, message: m);
        await tester.pumpAndSettle();

        final img = find.descendant(
          of: find.byType(MessageMediaContent),
          matching: find.byType(Image),
        );
        expect(img, findsOneWidget);
        final image = tester.widget<Image>(img);
        // Tamaño natural sin agrandar (scaleDown: encoge si excede, jamás
        // upscalea) dentro de un cuadro fijo de 140.
        expect(image.fit, BoxFit.scaleDown);
        expect(image.width, 140);
        expect(image.height, 140);
        // Sin ClipRRect: el sticker es transparente, no lleva esquinas de foto.
        expect(
          find.descendant(
            of: find.byType(MessageMediaContent),
            matching: find.byType(ClipRRect),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('sticker: tocar NO abre el visor fullscreen (no es una foto)', (
      tester,
    ) async {
      final cache = fakeMessageMediaCache(downloadResult: pngBytes);
      final m = ValueNotifier<Message>(
        msg(
          externalId: 's1',
          type: 'sticker',
          content: '',
          mediaRef: 'ref-s1',
          mediaUrl: 'https://cdn/s1.webp',
        ),
      );
      addTearDown(m.dispose);
      await pumpContent(tester, cache: cache, message: m);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('message.sticker.s1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('media_viewer')), findsNothing);
    });

    testWidgets(
      'sticker limpio (sin cita ni grupo): la burbuja flota sin fondo ni padding',
      (tester) async {
        await pumpMsg(
          tester,
          msg(
            externalId: 'sB',
            type: 'sticker',
            content: '',
            mediaRef: 'ref-sB',
            mediaUrl: 'https://cdn/sB.webp',
          ),
          cache: fakeMessageMediaCache(downloadResult: pngBytes),
        );
        await tester.pumpAndSettle();
        // El Container de burbuja que envuelve la media va SIN decoración ni
        // padding: el sticker flota transparente sobre el lienzo del hilo.
        final bubble = tester.widget<Container>(
          find
              .ancestor(
                of: find.byType(MessageMediaContent),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(bubble.decoration, isNull);
        expect(bubble.padding, EdgeInsets.zero);
      },
    );

    testWidgets(
      'sticker que es respuesta conserva la burbuja y dibuja la cita',
      (tester) async {
        await pumpMsg(
          tester,
          msg(
            externalId: 'sR',
            type: 'sticker',
            content: '',
            mediaRef: 'ref-sR',
            mediaUrl: 'https://cdn/sR.webp',
            quotedId: 'q1',
          ),
          cache: fakeMessageMediaCache(downloadResult: pngBytes),
        );
        await tester.pumpAndSettle();
        // Con cita, el sticker mantiene el chrome de burbuja (fondo surface2):
        // el bloque de cita necesita ese backdrop para ser legible.
        expect(
          find.descendant(
            of: find.byKey(const Key('message.sR')),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).color == AppTokens.surface2,
            ),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('message.quoted.sR')), findsOneWidget);
      },
    );

    testWidgets('sticker de grupo conserva la burbuja y muestra el autor', (
      tester,
    ) async {
      await pumpMsg(
        tester,
        msg(
          externalId: 'sG',
          kind: MessageKind.group,
          type: 'sticker',
          senderLid: 'bob',
          content: '',
          mediaRef: 'ref-sG',
          mediaUrl: 'https://cdn/sG.webp',
        ),
        cache: fakeMessageMediaCache(downloadResult: pngBytes),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('message.sG')),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color == AppTokens.surface2,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('bob'), findsOneWidget);
    });

    testWidgets('sticker sin bytes (offline) → "Sticker no disponible"', (
      tester,
    ) async {
      await pumpMsg(
        tester,
        // Sin mediaUrl ni caché: la resolución da null → tarjeta de fallback.
        msg(externalId: 'sN', type: 'sticker', content: '', mediaRef: 'ref-sN'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sticker no disponible'), findsOneWidget);
    });

    testWidgets('sticker sin bytes en pantalla angosta no desborda', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpMsg(
        tester,
        msg(
          externalId: 'sN2',
          type: 'sticker',
          content: '',
          mediaRef: 'ref-sN2',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'control: un texto inbound sí lleva fondo de burbuja surface2',
      (tester) async {
        await pumpMsg(
          tester,
          msg(externalId: 'tB', type: 'text', content: 'hola'),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const Key('message.tB')),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).color == AppTokens.surface2,
            ),
          ),
          findsOneWidget,
        );
      },
    );
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

  group('copiar / seleccionar texto (long-press)', () {
    testWidgets(
      'un texto ofrece Copiar y Seleccionar; Copiar va al portapapeles y avisa',
      (tester) async {
        final copied = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add(
                (call.arguments as Map<Object?, Object?>)['text'] as String,
              );
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );

        when(() => bloc.state).thenReturn(
          MessagesLoaded(
            items: <Message>[msg(externalId: 'm1', content: 'hola mundo')],
            prevCursor: null,
            isLoadingOlder: false,
          ),
        );
        await tester.pumpWidget(host());
        await tester.longPress(find.text('hola mundo'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('message.copy.m1')), findsOneWidget);
        expect(find.byKey(const Key('message.select.m1')), findsOneWidget);

        await tester.tap(find.byKey(const Key('message.copy.m1')));
        await tester.pumpAndSettle();

        expect(copied, <String>['hola mundo']);
        expect(find.text('Mensaje copiado'), findsOneWidget);
      },
    );

    testWidgets(
      'Seleccionar texto abre una superficie con texto seleccionable',
      (tester) async {
        when(() => bloc.state).thenReturn(
          MessagesLoaded(
            items: <Message>[
              msg(externalId: 'm1', content: 'texto largo del cliente'),
            ],
            prevCursor: null,
            isLoadingOlder: false,
          ),
        );
        await tester.pumpWidget(host());
        await tester.longPress(find.text('texto largo del cliente'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('message.select.m1')));
        await tester.pumpAndSettle();

        final selectable = tester.widget<SelectableText>(
          find.byKey(const Key('message.select_sheet.text')),
        );
        expect(selectable.data, 'texto largo del cliente');
      },
    );

    testWidgets(
      'un mensaje no-texto no ofrece copiar/seleccionar (sí reaccionar)',
      (tester) async {
        when(() => bloc.state).thenReturn(
          MessagesLoaded(
            items: <Message>[
              msg(
                externalId: 'img1',
                type: 'image',
                content: '',
                mediaRef: 'r/x',
              ),
            ],
            prevCursor: null,
            isLoadingOlder: false,
          ),
        );
        await tester.pumpWidget(host());
        await tester.longPress(
          find
              .descendant(
                of: find.byKey(const Key('message.img1')),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('message.copy.img1')), findsNothing);
        expect(find.byKey(const Key('message.select.img1')), findsNothing);
        expect(find.byKey(const Key('reaction.pick.img1.👍')), findsOneWidget);
      },
    );
  });

  group('drill-through al razonamiento (S24)', () {
    Widget hostRouted(AuthState authState) {
      when(() => authBloc.state).thenReturn(authState);
      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => RepositoryProvider<AudioRecorder>.value(
              value: const NoopAudioRecorder(),
              child: RepositoryProvider<MediaOpener>.value(
                value: opener,
                child: MultiBlocProvider(
                  providers: <BlocProvider<dynamic>>[
                    BlocProvider<MessagesBloc>.value(value: bloc),
                    BlocProvider<ThreadAudioCubit>.value(value: audio),
                    BlocProvider<AuthBloc>.value(value: authBloc),
                    BlocProvider<MonitorLiveCubit>(
                      create: (_) => MonitorLiveCubit(_FakeMonitorDs()),
                    ),
                  ],
                  child: const Scaffold(body: MessageThreadPage()),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/bots/:id/sessions/:chatLid/ai-log',
            builder: (_, _) => const Scaffold(body: Text('ai-log-stub')),
          ),
        ],
      );
      return MaterialApp.router(
        theme: AppDesignTheme.dark(),
        routerConfig: router,
      );
    }

    setUp(() {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[
            msg(
              externalId: 'om1',
              direction: MessageDirection.outbound,
              content: 'respuesta del bot',
            ),
          ],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      when(() => bloc.botId).thenReturn('b1');
      when(() => bloc.chatLid).thenReturn('lid-1');
    });

    testWidgets('ADMIN + OUTBOUND: ofrece "Ver razonamiento" y navega', (
      tester,
    ) async {
      await tester.pumpWidget(
        hostRouted(
          const AuthAuthenticated(
            Identity(userId: 'u', email: 'x@x', orgId: 'o', role: 'ADMIN'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('respuesta del bot'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('message.drill.om1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('message.drill.om1')));
      await tester.pumpAndSettle();
      expect(find.text('ai-log-stub'), findsOneWidget);
    });

    testWidgets('WORKER no ve el drill; la reacción sigue disponible', (
      tester,
    ) async {
      await tester.pumpWidget(
        hostRouted(
          const AuthAuthenticated(
            Identity(userId: 'u', email: 'x@x', orgId: 'o', role: 'WORKER'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('respuesta del bot'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('message.drill.om1')), findsNothing);
      expect(find.byKey(const Key('reaction.pick.om1.👍')), findsOneWidget);
    });

    testWidgets('INBOUND no ofrece drill aunque seas ADMIN', (tester) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[msg(externalId: 'im1', content: 'hola bot')],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(
        hostRouted(
          const AuthAuthenticated(
            Identity(userId: 'u', email: 'x@x', orgId: 'o', role: 'ADMIN'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('hola bot'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('message.drill.im1')), findsNothing);
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
      // La caja de redacción es la canónica del design system.
      expect(find.byType(AppChatComposer), findsOneWidget);
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

    testWidgets(
      'Responder fija la cita, muestra la barra y enviar lleva quotedId',
      (tester) async {
        when(() => bloc.state).thenReturn(
          MessagesLoaded(
            items: <Message>[
              msg(externalId: 'orig', senderLid: 'bob', content: 'el original'),
            ],
            prevCursor: null,
            isLoadingOlder: false,
          ),
        );
        await tester.pumpWidget(host());
        await tester.longPress(find.text('el original'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('message.reply.orig')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('composer.reply_bar')), findsOneWidget);
        expect(find.text('Respondiendo a bob'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('composer.input')),
          'respondo',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('composer.send')));
        await tester.pump();
        verify(
          () => bloc.add(
            const MessagesSendRequested(
              type: 'text',
              content: 'respondo',
              quotedId: 'orig',
            ),
          ),
        ).called(1);
        // Tras enviar, la cita se limpia y la barra desaparece.
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('composer.reply_bar')), findsNothing);
      },
    );

    testWidgets('cancelar la respuesta oculta la barra de cita', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[
            msg(externalId: 'orig', senderLid: 'bob', content: 'hola'),
          ],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());
      await tester.longPress(find.text('hola'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('message.reply.orig')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('composer.reply_bar')), findsOneWidget);

      await tester.tap(find.byKey(const Key('composer.reply_cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('composer.reply_bar')), findsNothing);
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
          RepositoryProvider<MediaOpener>.value(value: opener),
          RepositoryProvider<CameraCapture>.value(
            value: const NoopCameraCapture(),
          ),
          RepositoryProvider<DeviceGalleryPort>.value(
            value: const NoopDeviceGallery(),
          ),
          RepositoryProvider<AudioRecorder>.value(
            value: const NoopAudioRecorder(),
          ),
        ],
        child: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<MessagesBloc>.value(value: bloc),
            BlocProvider<ThreadAudioCubit>.value(value: audio),
            BlocProvider<MonitorLiveCubit>(
              create: (_) => MonitorLiveCubit(_FakeMonitorDs()),
            ),
          ],
          child: const Scaffold(body: MessageThreadPage()),
        ),
      ),
    );

    testWidgets('pick + upload → envía type:image con ref y caption', (
      tester,
    ) async {
      when(picker.pickMultiple).thenAnswer(
        (_) async => <PickedMedia>[
          PickedMedia(
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
            filename: 'foto.jpg',
          ),
        ],
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
      // El clip abre el menú de adjuntar; "Documento" dispara pickMultiple.
      await tester.tap(find.byKey(const Key('composer.attach')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attach_menu.document')));
      await tester.pumpAndSettle(); // cierra el sheet y llena la bandeja
      await tester.enterText(
        find.byKey(const Key('composer.input')),
        'mira esto',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('composer.send')));
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
      when(picker.pickMultiple).thenAnswer((_) async => <PickedMedia>[]);
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

  group('multimedia interaccionable', () {
    void seed(Message m) {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[m],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
    }

    testWidgets('audio con mediaRef: burbuja reproducible, tap → toggle', (
      tester,
    ) async {
      seed(
        msg(
          externalId: 'a1',
          type: 'ptt',
          mediaRef: 'ref-a1',
          mediaUrl: 'https://m/a.ogg',
        ),
      );
      when(
        () => audio.toggle(
          any(),
          bytes: any(named: 'bytes'),
          url: any(named: 'url'),
          contentType: any(named: 'contentType'),
          fallbackDuration: any(named: 'fallbackDuration'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(host());

      await tester.tap(find.byKey(const Key('message.audio.a1.toggle')));
      await tester.pumpAndSettle();
      // Identidad = mediaRef (no la URL efímera); la URL viaja como respaldo.
      verify(
        () => audio.toggle(
          'ref-a1',
          bytes: any(named: 'bytes'),
          url: 'https://m/a.ogg',
          contentType: any(named: 'contentType'),
          fallbackDuration: any(named: 'fallbackDuration'),
        ),
      ).called(1);
    });

    testWidgets('ptt con mediaRef SIN URL firmada: igual es reproducible', (
      tester,
    ) async {
      // Bug del lag: la burbuja se pinta y suena por mediaRef (copia local) sin
      // esperar la URL firmada — no la tarjeta de adjunto.
      seed(msg(externalId: 'a1', type: 'ptt', mediaRef: 'ref-a1', content: ''));

      await tester.pumpWidget(host());

      // El reproductor (toggle + barra), no la tarjeta de adjunto estática.
      expect(find.byKey(const Key('message.audio.a1.toggle')), findsOneWidget);
      expect(
        find.byKey(const Key('message.audio.a1.progress')),
        findsOneWidget,
      );
    });

    testWidgets('audio activo: ícono de pausa y barra de progreso buscable', (
      tester,
    ) async {
      seed(
        msg(
          externalId: 'a1',
          type: 'audio',
          mediaRef: 'ref-a1',
          mediaUrl: 'https://m/a.ogg',
        ),
      );
      when(() => audio.state).thenReturn(
        const ThreadAudioState(
          sourceKey: 'ref-a1',
          playing: true,
          position: Duration(seconds: 5),
          duration: Duration(seconds: 20),
        ),
      );

      await tester.pumpWidget(host());

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      final bar = tester.widget<Slider>(
        find.byKey(const Key('message.audio.a1.progress')),
      );
      expect(bar.value, closeTo(0.25, 0.001));
      expect(bar.onChanged, isNotNull); // activa ⇒ buscable
      expect(find.textContaining('0:05'), findsOneWidget); // posición en curso
    });

    testWidgets('audio activo: pill de velocidad; tap → cycleSpeed', (
      tester,
    ) async {
      seed(
        msg(
          externalId: 'a1',
          type: 'audio',
          mediaRef: 'ref-a1',
          mediaUrl: 'https://m/a.ogg',
        ),
      );
      when(() => audio.state).thenReturn(
        const ThreadAudioState(
          sourceKey: 'ref-a1',
          playing: true,
          position: Duration(seconds: 5),
          duration: Duration(seconds: 20),
          speed: 1.5,
        ),
      );
      when(() => audio.cycleSpeed()).thenAnswer((_) async {});

      await tester.pumpWidget(host());

      expect(find.text('1.5x'), findsOneWidget);
      await tester.tap(find.byKey(const Key('message.audio.a1.speed')));
      verify(() => audio.cycleSpeed()).called(1);
    });

    testWidgets('arrastrar la barra activa → seek', (tester) async {
      seed(
        msg(
          externalId: 'a1',
          type: 'audio',
          mediaRef: 'ref-a1',
          mediaUrl: 'https://m/a.ogg',
        ),
      );
      when(() => audio.state).thenReturn(
        const ThreadAudioState(
          sourceKey: 'ref-a1',
          playing: true,
          position: Duration(seconds: 5),
          duration: Duration(seconds: 20),
        ),
      );
      when(() => audio.seek(any())).thenAnswer((_) async {});

      await tester.pumpWidget(host());
      await tester.drag(
        find.byKey(const Key('message.audio.a1.progress')),
        const Offset(40, 0),
      );
      await tester.pumpAndSettle();

      verify(() => audio.seek(any())).called(greaterThanOrEqualTo(1));
    });

    testWidgets('audio inactivo: barra deshabilitada y sin pill', (
      tester,
    ) async {
      seed(
        msg(
          externalId: 'a1',
          type: 'audio',
          mediaRef: 'ref-a1',
          mediaUrl: 'https://m/a.ogg',
        ),
      );
      // El player está en OTRA fuente ⇒ esta burbuja está inactiva.
      when(() => audio.state).thenReturn(
        const ThreadAudioState(sourceKey: 'ref-otra', playing: true),
      );

      await tester.pumpWidget(host());

      final bar = tester.widget<Slider>(
        find.byKey(const Key('message.audio.a1.progress')),
      );
      expect(bar.onChanged, isNull); // inactiva ⇒ no buscable
      expect(find.byKey(const Key('message.audio.a1.speed')), findsNothing);
    });

    testWidgets('audio activo en pantalla angosta no desborda', (tester) async {
      // Caso real: split-screen / ~320dp. La burbuja activa (play + barra +
      // pill) debe encoger, no desbordar el ancho. Sin el Flexible la fila de
      // anchos fijos rebasa el cap del 78% del ancho.
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      seed(
        msg(
          externalId: 'a1',
          type: 'audio',
          mediaRef: 'ref-a1',
          mediaUrl: 'https://m/a.ogg',
        ),
      );
      when(() => audio.state).thenReturn(
        const ThreadAudioState(
          sourceKey: 'ref-a1',
          playing: true,
          position: Duration(seconds: 5),
          duration: Duration(seconds: 20),
          speed: 2.0,
        ),
      );

      await tester.pumpWidget(host());
      await tester.pump();

      expect(tester.takeException(), isNull); // sin RenderFlex overflow
      expect(find.byKey(const Key('message.audio.a1.toggle')), findsOneWidget);
    });

    testWidgets('audio sin mediaRef cae a la tarjeta de tipo', (tester) async {
      seed(msg(externalId: 'a1', type: 'audio'));
      await tester.pumpWidget(host());
      expect(find.text('Audio'), findsOneWidget);
      expect(find.byKey(const Key('message.audio.a1.toggle')), findsNothing);
    });

    testWidgets('audio que falla al cargar anuncia SnackBar', (tester) async {
      seed(
        msg(
          externalId: 'a1',
          type: 'audio',
          mediaRef: 'ref-a1',
          mediaUrl: 'https://m/a.ogg',
        ),
      );
      whenListen(
        audio,
        Stream<ThreadAudioState>.fromIterable(<ThreadAudioState>[
          const ThreadAudioState(failedKey: 'ref-a1'),
        ]),
        initialState: const ThreadAudioState(),
      );

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump();

      expect(find.text('No se pudo reproducir el audio'), findsOneWidget);
    });

    testWidgets('documento con mediaUrl: tap lo abre con la app externa', (
      tester,
    ) async {
      seed(
        msg(externalId: 'd1', type: 'document', mediaUrl: 'https://m/f.pdf'),
      );
      when(() => opener.open(url: any(named: 'url'))).thenAnswer((_) async {});

      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('message.doc.d1')));
      await tester.pumpAndSettle();

      verify(() => opener.open(url: 'https://m/f.pdf')).called(1);
    });

    testWidgets('video con mediaUrl: tap lo reproduce dentro de la app', (
      tester,
    ) async {
      seed(msg(externalId: 'v1', type: 'video', mediaUrl: 'https://m/v.mp4'));

      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('message.video.v1')));
      await tester.pump();

      expect(videoPlayback.calls, <String>['https://m/v.mp4']);
    });

    testWidgets('documento sin mediaUrl no es tocable (sin URL firmada)', (
      tester,
    ) async {
      seed(msg(externalId: 'd1', type: 'document', content: 'contrato.pdf'));
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('message.doc.d1')), findsNothing);
      // Sin URL firmada la tarjeta informa el nombre pero no es tocable.
      expect(find.text('contrato.pdf'), findsOneWidget);
    });

    testWidgets('fallo al abrir anuncia SnackBar', (tester) async {
      seed(
        msg(externalId: 'd1', type: 'document', mediaUrl: 'https://m/f.pdf'),
      );
      when(
        () => opener.open(url: any(named: 'url')),
      ).thenThrow(const MediaOpenException('sin app'));

      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('message.doc.d1')));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo abrir el archivo'), findsOneWidget);
    });

    testWidgets('imagen con mediaUrl: tap abre el visor y un tap lo cierra', (
      tester,
    ) async {
      seed(
        msg(
          externalId: 'i1',
          type: 'image',
          mediaRef: 'ref-i1',
          mediaUrl: 'https://m/i.jpg',
        ),
      );

      await tester.pumpWidget(
        host(mediaCache: fakeMessageMediaCache(downloadResult: _pngBytes)),
      );
      await tester.pumpAndSettle(); // resuelve la carga de bytes de la imagen
      await tester.tap(find.byKey(const Key('message.image.i1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('media_viewer')), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);

      await tester.tap(find.byKey(const Key('media_viewer.dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('media_viewer')), findsNothing);
    });
  });

  group('separadores de día', () {
    void seedItems(List<Message> items) {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(items: items, prevCursor: null, isLoadingOlder: false),
      );
    }

    int ms(DateTime dt) => dt.millisecondsSinceEpoch;

    testWidgets('mensajes de días distintos llevan separador por día', (
      tester,
    ) async {
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1, 22);
      seedItems(<Message>[
        msg(externalId: 'm1', content: 'de ayer', ts: ms(yesterday)),
        msg(externalId: 'm2', content: 'de hoy', ts: ms(today)),
      ]);
      await tester.pumpWidget(host());

      expect(find.text('Ayer'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
    });

    testWidgets('mensajes del mismo día comparten UN separador', (
      tester,
    ) async {
      final today = DateTime.now();
      seedItems(<Message>[
        msg(externalId: 'm1', content: 'uno', ts: ms(today) - 60000),
        msg(externalId: 'm2', content: 'dos', ts: ms(today)),
      ]);
      await tester.pumpWidget(host());

      expect(find.text('Hoy'), findsOneWidget);
    });
  });

  group('cola de burbuja (radios asimétricos)', () {
    BorderRadius radiusOf(WidgetTester tester, String ext) {
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(Key('message.$ext')),
              matching: find.byType(Container),
            )
            .first,
      );
      return (box.decoration! as BoxDecoration).borderRadius! as BorderRadius;
    }

    testWidgets('OUTBOUND lleva la cola abajo a la derecha', (tester) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[
            msg(externalId: 'e1', direction: MessageDirection.outbound),
          ],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());

      final r = radiusOf(tester, 'e1');
      expect(r.bottomRight.x, lessThan(r.bottomLeft.x));
    });

    testWidgets('INBOUND lleva la cola abajo a la izquierda', (tester) async {
      when(() => bloc.state).thenReturn(
        MessagesLoaded(
          items: <Message>[
            msg(externalId: 'e1', direction: MessageDirection.inbound),
          ],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      );
      await tester.pumpWidget(host());

      final r = radiusOf(tester, 'e1');
      expect(r.bottomLeft.x, lessThan(r.bottomRight.x));
    });
  });
  group('editar / eliminar (long-press, correcciones del operador)', () {
    MessagesLoaded loadedWith(Message m) => MessagesLoaded(
      items: <Message>[m],
      prevCursor: null,
      isLoadingOlder: false,
    );

    testWidgets(
      'un saliente de texto reciente ofrece Editar y Eliminar; guardar dispatcha',
      (tester) async {
        when(() => bloc.state).thenReturn(
          loadedWith(
            msg(
              externalId: 'm1',
              direction: MessageDirection.outbound,
              content: 'precio 40',
              ts: DateTime.now().millisecondsSinceEpoch,
              status: MessageStatus.sent,
            ),
          ),
        );
        await tester.pumpWidget(host());
        await tester.longPress(find.text('precio 40'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('message.edit.m1')), findsOneWidget);
        expect(find.byKey(const Key('message.delete.m1')), findsOneWidget);

        await tester.tap(find.byKey(const Key('message.edit.m1')));
        await tester.pumpAndSettle();

        // Diálogo prellenado con el texto actual.
        final field = tester.widget<TextField>(
          find.byKey(const Key('message.edit.field')),
        );
        expect(field.controller!.text, 'precio 40');

        await tester.enterText(
          find.byKey(const Key('message.edit.field')),
          'precio 50',
        );
        await tester.tap(find.byKey(const Key('message.edit.save')));
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(
            const MessagesEditRequested(messageId: 'm1', newText: 'precio 50'),
          ),
        ).called(1);
      },
    );

    testWidgets('fuera de la ventana de 15 min: sin Editar, sí Eliminar', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        loadedWith(
          msg(
            externalId: 'm1',
            direction: MessageDirection.outbound,
            content: 'viejo',
            ts: 1700, // epoch remoto: fuera de la ventana
            status: MessageStatus.sent,
          ),
        ),
      );
      await tester.pumpWidget(host());
      await tester.longPress(find.text('viejo'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('message.edit.m1')), findsNothing);
      expect(find.byKey(const Key('message.delete.m1')), findsOneWidget);
    });

    testWidgets('un INBOUND del cliente no ofrece corrección', (tester) async {
      when(() => bloc.state).thenReturn(
        loadedWith(
          msg(
            externalId: 'm1',
            content: 'soy el cliente',
            ts: DateTime.now().millisecondsSinceEpoch,
          ),
        ),
      );
      await tester.pumpWidget(host());
      await tester.longPress(find.text('soy el cliente'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('message.edit.m1')), findsNothing);
      expect(find.byKey(const Key('message.delete.m1')), findsNothing);
    });

    testWidgets('un mensaje ya revocado no ofrece corrección', (tester) async {
      when(() => bloc.state).thenReturn(
        loadedWith(
          msg(
            externalId: 'm1',
            direction: MessageDirection.outbound,
            content: 'borrado',
            ts: DateTime.now().millisecondsSinceEpoch,
            status: MessageStatus.sent,
            revokedAtMs: 999,
          ),
        ),
      );
      await tester.pumpWidget(host());
      await tester.longPress(find.text('Se eliminó este mensaje'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('message.edit.m1')), findsNothing);
      expect(find.byKey(const Key('message.delete.m1')), findsNothing);
    });

    testWidgets('Eliminar pide confirmación y dispatcha al confirmar', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        loadedWith(
          msg(
            externalId: 'm1',
            direction: MessageDirection.outbound,
            content: 'adiós',
            ts: DateTime.now().millisecondsSinceEpoch,
            status: MessageStatus.sent,
          ),
        ),
      );
      await tester.pumpWidget(host());
      await tester.longPress(find.text('adiós'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('message.delete.m1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('message.delete.confirm')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(const MessagesDeleteRequested(messageId: 'm1')),
      ).called(1);
    });

    testWidgets('una corrección fallida anuncia con copy honesto', (
      tester,
    ) async {
      final failures = StreamController<MessagesFailure>.broadcast();
      addTearDown(failures.close);
      when(() => bloc.correctionFailures).thenAnswer((_) => failures.stream);
      when(
        () => bloc.state,
      ).thenReturn(loadedWith(msg(externalId: 'm1', content: 'hola')));
      await tester.pumpWidget(host());

      failures.add(const MessagesConflictFailure());
      await tester.pumpAndSettle();

      expect(
        find.text('WhatsApp ya no permite editar ese mensaje'),
        findsOneWidget,
      );
    });
  });
}

// ===========================================================================
// Corrección y tipos ricos (S25): revocado, editado, encuesta, ubicación,
// contacto y voto. Se registran desde main() vía _richTypesGroup.
// ===========================================================================
