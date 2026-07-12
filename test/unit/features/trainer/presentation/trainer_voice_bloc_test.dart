import 'package:ataulfo/core/media/media_byte_sink.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_conversation.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_models.dart';
import 'package:ataulfo/features/trainer/domain/failures/trainer_failure.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/trainer_chat_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrainerRepo extends Mock implements TrainerRepository {}

/// Sink de prueba que registra las siembras (ref → bytes).
class _RecordingSink implements MediaByteSink {
  final Map<String, Uint8List> seeded = <String, Uint8List>{};

  @override
  Future<void> cache(String ref, Uint8List bytes) async {
    seeded[ref] = bytes;
  }
}

final _conv = TrainerConversation(
  id: 'c1',
  templateId: 't1',
  title: 'Entrenamiento',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

TrainerMessage _msg(String id, String role, String content) => TrainerMessage(
  id: id,
  conversationId: 'c1',
  role: role,
  content: content,
  createdAt: DateTime.utc(2026, 6, 10, 10),
);

TrainerMessage _voiceUser() => TrainerMessage(
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

  late _MockTrainerRepo repo;
  late _RecordingSink sink;

  setUp(() {
    repo = _MockTrainerRepo();
    sink = _RecordingSink();
  });

  TrainerChatBloc build() =>
      TrainerChatBloc(repo: repo, templateId: 't1', mediaSink: sink);

  TrainerChatLoaded loaded() => TrainerChatLoaded(
    conversation: _conv,
    conversations: <TrainerConversation>[_conv],
    messages: const <TrainerMessage>[],
    sending: false,
  );

  group('nota de voz', () {
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

    blocTest<TrainerChatBloc, TrainerChatState>(
      'VoiceStarted marca recordingVoice',
      build: build,
      seed: loaded,
      act: (b) => b.add(const TrainerChatVoiceStarted()),
      expect: () => <dynamic>[
        isA<TrainerChatLoaded>().having(
          (s) => s.recordingVoice,
          'recording',
          true,
        ),
      ],
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'grabando bloquea el envío de texto (una cosa a la vez)',
      build: build,
      seed: () => loaded().copyWith(recordingVoice: true),
      act: (b) => b.add(const TrainerChatMessageSent('hola')),
      expect: () => <dynamic>[],
      verify: (_) {
        verifyNever(
          () => repo.sendMessage(
            templateId: any(named: 'templateId'),
            conversationId: any(named: 'conversationId'),
            content: any(named: 'content'),
            attachments: any(named: 'attachments'),
          ),
        );
      },
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'VoiceCancelled limpia recordingVoice',
      build: build,
      seed: () => loaded().copyWith(recordingVoice: true),
      act: (b) => b.add(const TrainerChatVoiceCancelled()),
      expect: () => <dynamic>[
        isA<TrainerChatLoaded>().having(
          (s) => s.recordingVoice,
          'recording',
          false,
        ),
      ],
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'VoiceSent sin grabación previa se ignora (no corre turno espurio)',
      build: build,
      seed: loaded, // recordingVoice: false por defecto
      act: (b) => b.add(TrainerChatVoiceSent(bytes)),
      expect: () => <dynamic>[],
      verify: (_) {
        verifyNever(
          () => repo.sendAudio(
            templateId: any(named: 'templateId'),
            conversationId: any(named: 'conversationId'),
            bytes: any(named: 'bytes'),
            filename: any(named: 'filename'),
          ),
        );
      },
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'VoiceSent corre el turno vía sendAudio y cierra con el assistant',
      build: build,
      seed: () => loaded().copyWith(recordingVoice: true),
      setUp: () {
        when(
          () => repo.sendAudio(
            templateId: 't1',
            conversationId: 'c1',
            bytes: any(named: 'bytes'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((_) async => _msg('a1', 'assistant', 'te escuché'));
        when(
          () => repo.listMessages(
            templateId: 't1',
            conversationId: 'c1',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => TrainerMessagesPage(
            messages: <TrainerMessage>[
              _msg('a1', 'assistant', 'te escuché'),
              _msg('u1', 'user', 'nota de voz'),
            ],
            nextCursor: '',
          ),
        );
      },
      act: (b) => b.add(TrainerChatVoiceSent(bytes)),
      expect: () => <dynamic>[
        // Arranca el turno: recording cae, sending sube, traza viva vacía.
        isA<TrainerChatLoaded>()
            .having((s) => s.recordingVoice, 'recording', false)
            .having((s) => s.sending, 'sending', true)
            .having((s) => s.liveEvents, 'sin eventos aún', isEmpty),
        // Cierra con el assistant que devolvió el POST.
        isA<TrainerChatLoaded>()
            .having((s) => s.sending, 'sending', false)
            .having(
              (s) => s.messages.any((m) => m.id == 'a1'),
              'assistant',
              true,
            ),
        // Recarga best-effort del hilo completo.
        isA<TrainerChatLoaded>().having(
          (s) => s.messages.any((m) => m.id == 'u1'),
          'user recargado',
          true,
        ),
      ],
      verify: (_) {
        verify(
          () => repo.sendAudio(
            templateId: 't1',
            conversationId: 'c1',
            bytes: any(named: 'bytes'),
            filename: any(named: 'filename'),
          ),
        ).called(1);
      },
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'VoiceSent con fallo del motor revierte a un fallo mostrable',
      build: build,
      seed: () => loaded().copyWith(recordingVoice: true),
      setUp: () {
        when(
          () => repo.sendAudio(
            templateId: 't1',
            conversationId: 'c1',
            bytes: any(named: 'bytes'),
            filename: any(named: 'filename'),
          ),
        ).thenThrow(const TrainerEngineFailure());
      },
      act: (b) => b.add(TrainerChatVoiceSent(bytes)),
      expect: () => <dynamic>[
        isA<TrainerChatLoaded>().having((s) => s.sending, 'sending', true),
        isA<TrainerChatLoaded>()
            .having((s) => s.sending, 'sending', false)
            .having((s) => s.sendFailure, 'fallo', isA<TrainerEngineFailure>()),
      ],
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'enviar nota de voz siembra los bytes grabados bajo su audio_ref',
      build: build,
      setUp: () {
        when(
          () => repo.listConversations(templateId: 't1'),
        ).thenAnswer((_) async => <TrainerConversation>[_conv]);
        when(() => repo.listModels(templateId: 't1')).thenAnswer(
          (_) async => const TrainerModels(
            options: <TrainerModelOption>[],
            defaultId: '',
          ),
        );
        when(
          () => repo.sendAudio(
            templateId: 't1',
            conversationId: 'c1',
            bytes: any(named: 'bytes'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((_) async => _msg('a1', 'assistant', 'la escuché'));
        // La recarga post-turno trae el user de voz con su audio_ref.
        when(
          () => repo.listMessages(
            templateId: 't1',
            conversationId: 'c1',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => TrainerMessagesPage(
            messages: <TrainerMessage>[
              _msg('a1', 'assistant', 'la escuché'),
              _voiceUser(),
            ],
            nextCursor: '',
          ),
        );
      },
      act: (b) async {
        b.add(const TrainerChatStarted());
        await Future<void>.delayed(Duration.zero);
        // El envío exige una grabación en curso (guarda anti-espurio).
        b.add(const TrainerChatVoiceStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(TrainerChatVoiceSent(Uint8List.fromList(<int>[9, 9, 9])));
      },
      wait: const Duration(milliseconds: 10),
      verify: (b) {
        expect(
          sink.seeded['org/media/nota.ogg'],
          Uint8List.fromList(<int>[9, 9, 9]),
        );
      },
    );
  });
}
