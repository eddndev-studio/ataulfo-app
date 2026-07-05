import 'package:ataulfo/core/media/media_byte_sink.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_attachment.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_conversation.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_message.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_models.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_progress.dart';
import 'package:ataulfo/features/platform_agent/domain/repositories/platform_agent_repository.dart';
import 'package:ataulfo/features/platform_agent/presentation/bloc/platform_agent_chat_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PlatformAgentRepository {}

class _MockEvents extends Mock implements PlatformAgentEvents {}

class _MockPicker extends Mock implements MediaFilePicker {}

/// Sink de bytes que registra las siembras (ref → bytes).
class _RecordingSink implements MediaByteSink {
  final Map<String, Uint8List> seeded = <String, Uint8List>{};

  @override
  Future<void> cache(String ref, Uint8List bytes) async {
    seeded[ref] = bytes;
  }
}

PaConversation _conv({String id = 'c1'}) => PaConversation(
  id: id,
  title: 'Operación',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

const _att = PaAttachment(
  ref: 'org/media/a1.png',
  mime: 'image/png',
  name: 'catalogo.png',
  sizeBytes: 4,
);

PaMessage _assistant() => PaMessage(
  id: 'mx',
  conversationId: 'c1',
  role: 'assistant',
  content: 'la escuché',
  createdAt: DateTime.utc(2026, 6, 10, 10),
);

PaMessage _voiceUser() => PaMessage(
  id: 'mv',
  conversationId: 'c1',
  role: 'user',
  content: '[audio]',
  audioRef: 'org/media/nota.ogg',
  transcriptStatus: 'done',
  transcript: 'hola',
  createdAt: DateTime.utc(2026, 6, 10, 9, 59),
);

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  late _MockRepo repo;
  late _MockEvents events;
  late _MockPicker picker;
  late _RecordingSink sink;

  setUp(() {
    repo = _MockRepo();
    events = _MockEvents();
    picker = _MockPicker();
    sink = _RecordingSink();
    when(
      () => events.progress(any()),
    ).thenAnswer((_) => const Stream<PaProgressEvent>.empty());
    when(
      () => repo.listConversations(),
    ).thenAnswer((_) async => <PaConversation>[_conv()]);
    when(() => repo.listModels()).thenAnswer(
      (_) async => const PaModels(options: <PaModelOption>[], defaultId: ''),
    );
    when(
      () => repo.listMessages(
        conversationId: any(named: 'conversationId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async =>
          const PaMessagesPage(messages: <PaMessage>[], nextCursor: ''),
    );
  });

  PlatformAgentChatBloc build() => PlatformAgentChatBloc(
    repo: repo,
    events: events,
    picker: picker,
    mediaSink: sink,
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'subir un adjunto siembra sus bytes en el sink bajo su ref',
    build: build,
    setUp: () {
      when(() => picker.pickMultiple()).thenAnswer(
        (_) async => <PickedMedia>[
          PickedMedia(
            bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
            filename: 'catalogo.png',
          ),
        ],
      );
      when(
        () => repo.uploadAttachment(
          bytes: any(named: 'bytes'),
          filename: 'catalogo.png',
        ),
      ).thenAnswer((_) async => _att);
    },
    act: (b) async {
      b.add(const PaChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const PaChatAttachRequested());
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      expect(sink.seeded[_att.ref], Uint8List.fromList(<int>[1, 2, 3, 4]));
    },
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'enviar nota de voz siembra los bytes grabados bajo su audio_ref',
    build: build,
    setUp: () {
      when(
        () => repo.sendAudio(
          conversationId: 'c1',
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      ).thenAnswer((_) async => _assistant());
      // La recarga post-turno trae el user de voz con su audio_ref.
      when(
        () => repo.listMessages(
          conversationId: 'c1',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => PaMessagesPage(
          messages: <PaMessage>[_voiceUser(), _assistant()],
          nextCursor: '',
        ),
      );
    },
    act: (b) async {
      b.add(const PaChatStarted());
      await Future<void>.delayed(Duration.zero);
      // El envío exige una grabación en curso (guarda anti-espurio).
      b.add(const PaChatVoiceStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(PaChatVoiceSent(Uint8List.fromList(<int>[9, 9, 9])));
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      expect(
        sink.seeded['org/media/nota.ogg'],
        Uint8List.fromList(<int>[9, 9, 9]),
      );
    },
  );
}
