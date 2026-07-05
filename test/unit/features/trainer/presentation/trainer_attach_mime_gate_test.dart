import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_attachment.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_conversation.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_models.dart';
import 'package:ataulfo/features/trainer/domain/failures/trainer_failure.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/trainer_chat_bloc.dart';
import 'package:ataulfo/features/trainer/presentation/pages/trainer_chat_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrainerRepo extends Mock implements TrainerRepository {}

class _MockPicker extends Mock implements MediaFilePicker {}

final _conv = TrainerConversation(
  id: 'c1',
  templateId: 't1',
  title: 'Entrenamiento',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

const _mp4 = TrainerAttachment(
  ref: 'tenant/org/media/v1.mp4',
  mime: 'video/mp4',
  name: 'demo.mp4',
  sizeBytes: 4,
);

const _png = TrainerAttachment(
  ref: 'tenant/org/media/a1.png',
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

  setUp(() {
    repo = _MockTrainerRepo();
    picker = _MockPicker();
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

  TrainerChatBloc build() =>
      TrainerChatBloc(repo: repo, templateId: 't1', picker: picker);

  blocTest<TrainerChatBloc, TrainerChatState>(
    'video mp4 pasa el gate: se sube y crece pendingAttachments',
    build: build,
    setUp: () {
      when(() => picker.pickMultiple()).thenAnswer(
        (_) async => <PickedMedia>[
          PickedMedia(bytes: Uint8List(4), filename: 'demo.MP4'),
        ],
      );
      when(
        () => repo.uploadAttachment(
          templateId: 't1',
          bytes: any(named: 'bytes'),
          filename: 'demo.MP4',
        ),
      ).thenAnswer((_) async => _mp4);
    },
    act: (b) async {
      b.add(const TrainerChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const TrainerChatAttachRequested());
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      final s = b.state as TrainerChatLoaded;
      expect(s.pendingAttachments, <TrainerAttachment>[_mp4]);
      expect(s.attaching, isFalse);
      expect(s.sendFailure, isNull);
      // Sin miniatura local: solo las imágenes la siembran.
      expect(s.pendingThumbnails[_mp4.ref], isNull);
    },
  );

  blocTest<TrainerChatBloc, TrainerChatState>(
    'audio crudo (mp3) NO pasa el gate: nada se sube y se avisa tipo no '
    'soportado',
    build: build,
    setUp: () {
      when(() => picker.pickMultiple()).thenAnswer(
        (_) async => <PickedMedia>[
          PickedMedia(bytes: Uint8List(4), filename: 'nota.mp3'),
        ],
      );
    },
    act: (b) async {
      b.add(const TrainerChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const TrainerChatAttachRequested());
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      final s = b.state as TrainerChatLoaded;
      expect(s.pendingAttachments, isEmpty);
      expect(s.sendFailure, const TrainerAttachmentUnsupportedFailure());
      expect(s.attaching, isFalse);
      verifyNever(
        () => repo.uploadAttachment(
          templateId: any(named: 'templateId'),
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      );
    },
  );

  blocTest<TrainerChatBloc, TrainerChatState>(
    'lote mixto: sube lo soportado y avisa por lo rechazado',
    build: build,
    setUp: () {
      when(() => picker.pickMultiple()).thenAnswer(
        (_) async => <PickedMedia>[
          PickedMedia(bytes: Uint8List(4), filename: 'catalogo.png'),
          PickedMedia(bytes: Uint8List(4), filename: 'nota.mp3'),
        ],
      );
      when(
        () => repo.uploadAttachment(
          templateId: 't1',
          bytes: any(named: 'bytes'),
          filename: 'catalogo.png',
        ),
      ).thenAnswer((_) async => _png);
    },
    act: (b) async {
      b.add(const TrainerChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const TrainerChatAttachRequested());
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      final s = b.state as TrainerChatLoaded;
      expect(s.pendingAttachments, <TrainerAttachment>[_png]);
      expect(s.sendFailure, const TrainerAttachmentUnsupportedFailure());
      expect(s.attaching, isFalse);
      verifyNever(
        () => repo.uploadAttachment(
          templateId: any(named: 'templateId'),
          bytes: any(named: 'bytes'),
          filename: 'nota.mp3',
        ),
      );
    },
  );

  test('copy de tipo no soportado menciona video', () {
    expect(
      trainerFailureCopy(const TrainerAttachmentUnsupportedFailure()),
      'Tipo no soportado (imagen JPG/PNG/WebP, video MP4 o PDF).',
    );
  });
}
