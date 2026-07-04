import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_attachment.dart';
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
      when(() => picker.pickMultiple()).thenAnswer(
        (_) async => <PickedMedia>[
          PickedMedia(bytes: Uint8List(4), filename: 'catalogo.png'),
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
      final s = b.state as TrainerChatLoaded;
      expect(s.pendingAttachments, <TrainerAttachment>[_att]);
      expect(s.attaching, isFalse);
      // Miniatura local conservada por ref para el chip (imagen).
      expect(s.pendingThumbnails[_att.ref], isNotNull);
    },
  );

  blocTest<TrainerChatBloc, TrainerChatState>(
    'cancelar el picker no toca el estado',
    build: build,
    setUp: () {
      when(
        () => picker.pickMultiple(),
      ).thenAnswer((_) async => <PickedMedia>[]);
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
      when(() => picker.pickMultiple()).thenAnswer(
        (_) async => <PickedMedia>[
          PickedMedia(bytes: Uint8List(4), filename: 'catalogo.png'),
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
      when(() => picker.pickMultiple()).thenAnswer(
        (_) async => <PickedMedia>[
          PickedMedia(bytes: Uint8List(4), filename: 'catalogo.png'),
        ],
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
      expect(s.pendingThumbnails, isEmpty);
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

  TrainerAttachment imgFor(String name) => TrainerAttachment(
    ref: 'ref/$name',
    mime: 'image/png',
    name: name,
    sizeBytes: 4,
  );

  void stubUploadEcho() {
    when(
      () => repo.uploadAttachment(
        templateId: 't1',
        bytes: any(named: 'bytes'),
        filename: any(named: 'filename'),
      ),
    ).thenAnswer(
      (inv) async => imgFor(inv.namedArguments[#filename] as String),
    );
  }

  blocTest<TrainerChatBloc, TrainerChatState>(
    'multi-pick sube secuencial todos los del lote dentro del cupo',
    build: build,
    setUp: () {
      when(() => picker.pickMultiple()).thenAnswer(
        (_) async => <PickedMedia>[
          PickedMedia(bytes: Uint8List(4), filename: 'a.png'),
          PickedMedia(bytes: Uint8List(4), filename: 'b.png'),
          PickedMedia(bytes: Uint8List(4), filename: 'c.png'),
        ],
      );
      stubUploadEcho();
    },
    act: (b) async {
      b.add(const TrainerChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const TrainerChatAttachRequested());
    },
    wait: const Duration(milliseconds: 20),
    verify: (b) {
      final s = b.state as TrainerChatLoaded;
      expect(s.pendingAttachments.map((a) => a.name), <String>[
        'a.png',
        'b.png',
        'c.png',
      ]);
      expect(s.sendFailure, isNull);
      verify(
        () => repo.uploadAttachment(
          templateId: 't1',
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      ).called(3);
    },
  );

  blocTest<TrainerChatBloc, TrainerChatState>(
    'lote que excede el tope de 5 sube hasta llenar y avisa',
    build: build,
    setUp: () {
      when(() => picker.pickMultiple()).thenAnswer(
        (_) async => <PickedMedia>[
          for (var i = 0; i < 7; i++)
            PickedMedia(bytes: Uint8List(4), filename: 'f$i.png'),
        ],
      );
      stubUploadEcho();
    },
    act: (b) async {
      b.add(const TrainerChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const TrainerChatAttachRequested());
    },
    wait: const Duration(milliseconds: 30),
    verify: (b) {
      final s = b.state as TrainerChatLoaded;
      expect(s.pendingAttachments, hasLength(5));
      expect(s.sendFailure, isA<TrainerAttachmentLimitFailure>());
      verify(
        () => repo.uploadAttachment(
          templateId: 't1',
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      ).called(5);
    },
  );

  blocTest<TrainerChatBloc, TrainerChatState>(
    'archivo sobre 25MB se descarta ANTES de subir y avisa; el resto sube',
    build: build,
    setUp: () {
      when(() => picker.pickMultiple()).thenAnswer(
        (_) async => <PickedMedia>[
          PickedMedia(bytes: Uint8List(26 * 1024 * 1024), filename: 'big.png'),
          PickedMedia(bytes: Uint8List(4), filename: 'ok.png'),
        ],
      );
      stubUploadEcho();
    },
    act: (b) async {
      b.add(const TrainerChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const TrainerChatAttachRequested());
    },
    wait: const Duration(milliseconds: 20),
    verify: (b) {
      final s = b.state as TrainerChatLoaded;
      expect(s.pendingAttachments.map((a) => a.name), <String>['ok.png']);
      expect(s.sendFailure, isA<TrainerAttachmentTooLargeFailure>());
      verify(
        () => repo.uploadAttachment(
          templateId: 't1',
          bytes: any(named: 'bytes'),
          filename: 'ok.png',
        ),
      ).called(1);
      verifyNever(
        () => repo.uploadAttachment(
          templateId: 't1',
          bytes: any(named: 'bytes'),
          filename: 'big.png',
        ),
      );
    },
  );

  group('modalityWarning', () {
    TrainerChatLoaded loaded({
      required List<TrainerModelOption> models,
      required String selectedModelId,
      required List<TrainerAttachment> pending,
      String defaultModelId = '',
    }) => TrainerChatLoaded(
      conversation: _conv,
      messages: const <TrainerMessage>[],
      sending: false,
      models: models,
      defaultModelId: defaultModelId,
      selectedModelId: selectedModelId,
      pendingAttachments: pending,
    );

    test('modelo sin visión + imagen pendiente ⇒ aviso', () {
      final s = loaded(
        models: const <TrainerModelOption>[
          TrainerModelOption(
            id: 'm3',
            label: 'MiniMax M3',
            imageInput: false,
            pdfInput: false,
          ),
        ],
        selectedModelId: 'm3',
        pending: const <TrainerAttachment>[_att],
      );
      expect(s.modalityWarning, isNotEmpty);
      expect(s.modalityWarning.toLowerCase(), contains('imágenes'));
    });

    test('flags null (wire viejo) ⇒ sin aviso', () {
      final s = loaded(
        models: const <TrainerModelOption>[
          TrainerModelOption(id: 'm3', label: 'MiniMax M3'),
        ],
        selectedModelId: 'm3',
        pending: const <TrainerAttachment>[_att],
      );
      expect(s.modalityWarning, isEmpty);
    });

    test('modelo con visión ⇒ sin aviso', () {
      final s = loaded(
        models: const <TrainerModelOption>[
          TrainerModelOption(
            id: 'g',
            label: 'Gemini',
            imageInput: true,
            pdfInput: true,
          ),
        ],
        selectedModelId: 'g',
        pending: const <TrainerAttachment>[_att],
      );
      expect(s.modalityWarning, isEmpty);
    });

    test('sin pendientes ⇒ sin aviso', () {
      final s = loaded(
        models: const <TrainerModelOption>[
          TrainerModelOption(
            id: 'm3',
            label: 'MiniMax M3',
            imageInput: false,
            pdfInput: false,
          ),
        ],
        selectedModelId: 'm3',
        pending: const <TrainerAttachment>[],
      );
      expect(s.modalityWarning, isEmpty);
    });
  });
}
