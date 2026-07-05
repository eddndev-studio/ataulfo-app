import 'package:ataulfo/core/media/media_byte_sink.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_attachment.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_conversation.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_models.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/trainer_chat_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrainerRepo extends Mock implements TrainerRepository {}

class _MockPicker extends Mock implements MediaFilePicker {}

/// Sink de bytes que registra las siembras (ref → bytes).
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

const _att = TrainerAttachment(
  ref: 'org/media/a1.png',
  mime: 'image/png',
  name: 'catalogo.png',
  sizeBytes: 4,
);

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  late _MockTrainerRepo repo;
  late _MockPicker picker;
  late _RecordingSink sink;

  setUp(() {
    repo = _MockTrainerRepo();
    picker = _MockPicker();
    sink = _RecordingSink();
    when(
      () => repo.listConversations(templateId: 't1'),
    ).thenAnswer((_) async => <TrainerConversation>[_conv]);
    when(() => repo.listModels(templateId: 't1')).thenAnswer(
      (_) async =>
          const TrainerModels(options: <TrainerModelOption>[], defaultId: ''),
    );
    when(
      () => repo.listMessages(
        templateId: 't1',
        conversationId: 'c1',
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => const TrainerMessagesPage(
        messages: <TrainerMessage>[],
        nextCursor: '',
      ),
    );
  });

  blocTest<TrainerChatBloc, TrainerChatState>(
    'subir un adjunto siembra sus bytes en el sink bajo su ref',
    build: () => TrainerChatBloc(
      repo: repo,
      templateId: 't1',
      picker: picker,
      mediaSink: sink,
    ),
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
          templateId: 't1',
          bytes: any(named: 'bytes'),
          filename: 'catalogo.png',
        ),
      ).thenAnswer((_) async => _att);
    },
    act: (b) async {
      b.add(const TrainerChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const TrainerChatAttachRequested());
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      expect(sink.seeded[_att.ref], Uint8List.fromList(<int>[1, 2, 3, 4]));
    },
  );
}
