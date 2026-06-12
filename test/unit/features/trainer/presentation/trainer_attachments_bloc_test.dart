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

final _conv = TrainerConversation(
  id: 'c1',
  templateId: 't1',
  title: 'Entrenamiento',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

const _att = TrainerAttachment(
  ref: 'tenant/org/media/a1.png',
  mime: 'image/png',
  name: 'catalogo.png',
  sizeBytes: 4,
);

TrainerMessage _assistant() => TrainerMessage(
  id: 'mx',
  conversationId: 'c1',
  role: 'assistant',
  content: 'la veo',
  createdAt: DateTime.utc(2026, 6, 10, 10),
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
    'adjuntar: pick → upload → pendingAttachments crece',
    build: build,
    setUp: () {
      when(() => picker.pick()).thenAnswer(
        (_) async => PickedMedia(bytes: Uint8List(4), filename: 'catalogo.png'),
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
      final s = b.state as TrainerChatLoaded;
      expect(s.pendingAttachments, <TrainerAttachment>[_att]);
      expect(s.attaching, isFalse);
    },
  );

  blocTest<TrainerChatBloc, TrainerChatState>(
    'cancelar el picker no toca el estado',
    build: build,
    setUp: () {
      when(() => picker.pick()).thenAnswer((_) async => null);
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
    'quitar un adjunto pendiente lo saca de la lista',
    build: build,
    setUp: () {
      when(() => picker.pick()).thenAnswer(
        (_) async => PickedMedia(bytes: Uint8List(4), filename: 'catalogo.png'),
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
      await Future<void>.delayed(const Duration(milliseconds: 5));
      b.add(const TrainerChatAttachmentRemoved('tenant/org/media/a1.png'));
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      expect((b.state as TrainerChatLoaded).pendingAttachments, isEmpty);
    },
  );

  blocTest<TrainerChatBloc, TrainerChatState>(
    'enviar manda las refs y limpia los pendientes; el optimista pinta chips',
    build: build,
    setUp: () {
      when(() => picker.pick()).thenAnswer(
        (_) async => PickedMedia(bytes: Uint8List(4), filename: 'catalogo.png'),
      );
      when(
        () => repo.uploadAttachment(
          templateId: 't1',
          bytes: any(named: 'bytes'),
          filename: 'catalogo.png',
        ),
      ).thenAnswer((_) async => _att);
      when(
        () => repo.sendMessage(
          templateId: 't1',
          conversationId: 'c1',
          content: 'mira',
          attachments: const <String>['tenant/org/media/a1.png'],
        ),
      ).thenAnswer((_) async {
        // Tras el turno, el reload trae la verdad del server: el user con
        // sus adjuntos sellados + el assistant.
        when(
          () => repo.listMessages(
            templateId: 't1',
            conversationId: 'c1',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => TrainerMessagesPage(
            messages: <TrainerMessage>[
              _assistant(),
              TrainerMessage(
                id: 'm1',
                conversationId: 'c1',
                role: 'user',
                content: 'mira',
                attachments: const <TrainerAttachment>[_att],
                createdAt: DateTime.utc(2026, 6, 10, 10),
              ),
            ],
            nextCursor: '',
          ),
        );
        return _assistant();
      });
    },
    act: (b) async {
      b.add(const TrainerChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const TrainerChatAttachRequested());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      b.add(const TrainerChatMessageSent('mira'));
    },
    wait: const Duration(milliseconds: 20),
    verify: (b) {
      final s = b.state as TrainerChatLoaded;
      expect(s.pendingAttachments, isEmpty);
      verify(
        () => repo.sendMessage(
          templateId: 't1',
          conversationId: 'c1',
          content: 'mira',
          attachments: const <String>['tenant/org/media/a1.png'],
        ),
      ).called(1);
      final user = s.messages.firstWhere((m) => m.isUser);
      expect(user.attachments, <TrainerAttachment>[_att]);
    },
  );
}
