import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_attachment.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_conversation.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_message.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_models.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_progress.dart';
import 'package:ataulfo/features/platform_agent/domain/failures/pa_failure.dart';
import 'package:ataulfo/features/platform_agent/domain/repositories/platform_agent_repository.dart';
import 'package:ataulfo/features/platform_agent/presentation/bloc/platform_agent_chat_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PlatformAgentRepository {}

class _MockEvents extends Mock implements PlatformAgentEvents {}

class _MockPicker extends Mock implements MediaFilePicker {}

PaConversation _conv({String id = 'c1'}) => PaConversation(
  id: id,
  title: 'Operación',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

const _att = PaAttachment(
  ref: 'tenant/org/media/a1.png',
  mime: 'image/png',
  name: 'catalogo.png',
  sizeBytes: 4,
);

PaMessage _assistant() => PaMessage(
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

  late _MockRepo repo;
  late _MockEvents events;
  late _MockPicker picker;

  setUp(() {
    repo = _MockRepo();
    events = _MockEvents();
    picker = _MockPicker();
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

  PlatformAgentChatBloc build() =>
      PlatformAgentChatBloc(repo: repo, events: events, picker: picker);

  blocTest<PlatformAgentChatBloc, PaChatState>(
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
      final s = b.state as PaChatLoaded;
      expect(s.pendingAttachments, <PaAttachment>[_att]);
      expect(s.attaching, isFalse);
      // Miniatura local conservada por ref para el chip (imagen).
      expect(s.pendingThumbnails[_att.ref], isNotNull);
    },
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'cancelar el picker no toca el estado',
    build: build,
    setUp: () {
      when(
        () => picker.pickMultiple(),
      ).thenAnswer((_) async => <PickedMedia>[]);
    },
    act: (b) async {
      b.add(const PaChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const PaChatAttachRequested());
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      final s = b.state as PaChatLoaded;
      expect(s.pendingAttachments, isEmpty);
      verifyNever(
        () => repo.uploadAttachment(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      );
    },
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
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
          bytes: any(named: 'bytes'),
          filename: 'catalogo.png',
        ),
      ).thenAnswer((_) async => _att);
    },
    act: (b) async {
      b.add(const PaChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const PaChatAttachRequested());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      b.add(const PaChatAttachmentRemoved('tenant/org/media/a1.png'));
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      expect((b.state as PaChatLoaded).pendingAttachments, isEmpty);
    },
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
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
          bytes: any(named: 'bytes'),
          filename: 'catalogo.png',
        ),
      ).thenAnswer((_) async => _att);
      when(
        () => repo.sendMessage(
          conversationId: 'c1',
          content: 'mira',
          attachments: const <String>['tenant/org/media/a1.png'],
        ),
      ).thenAnswer((_) async {
        when(
          () => repo.listMessages(
            conversationId: 'c1',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => PaMessagesPage(
            messages: <PaMessage>[
              _assistant(),
              PaMessage(
                id: 'm1',
                conversationId: 'c1',
                role: 'user',
                content: 'mira',
                attachments: const <PaAttachment>[_att],
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
      b.add(const PaChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const PaChatAttachRequested());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      b.add(const PaChatMessageSent('mira'));
    },
    wait: const Duration(milliseconds: 20),
    verify: (b) {
      final s = b.state as PaChatLoaded;
      expect(s.pendingAttachments, isEmpty);
      expect(s.pendingThumbnails, isEmpty);
      verify(
        () => repo.sendMessage(
          conversationId: 'c1',
          content: 'mira',
          attachments: const <String>['tenant/org/media/a1.png'],
        ),
      ).called(1);
      final user = s.messages.firstWhere((m) => m.isUser);
      expect(user.attachments, <PaAttachment>[_att]);
    },
  );

  PaAttachment imgFor(String name) => PaAttachment(
    ref: 'ref/$name',
    mime: 'image/png',
    name: name,
    sizeBytes: 4,
  );

  void stubUploadEcho() {
    when(
      () => repo.uploadAttachment(
        bytes: any(named: 'bytes'),
        filename: any(named: 'filename'),
      ),
    ).thenAnswer(
      (inv) async => imgFor(inv.namedArguments[#filename] as String),
    );
  }

  blocTest<PlatformAgentChatBloc, PaChatState>(
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
      b.add(const PaChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const PaChatAttachRequested());
    },
    wait: const Duration(milliseconds: 20),
    verify: (b) {
      final s = b.state as PaChatLoaded;
      expect(s.pendingAttachments.map((a) => a.name), <String>[
        'a.png',
        'b.png',
        'c.png',
      ]);
      expect(s.sendFailure, isNull);
      verify(
        () => repo.uploadAttachment(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      ).called(3);
    },
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
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
      b.add(const PaChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const PaChatAttachRequested());
    },
    wait: const Duration(milliseconds: 30),
    verify: (b) {
      final s = b.state as PaChatLoaded;
      expect(s.pendingAttachments, hasLength(5));
      expect(s.sendFailure, isA<PaAttachmentLimitFailure>());
      verify(
        () => repo.uploadAttachment(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      ).called(5);
    },
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
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
      b.add(const PaChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const PaChatAttachRequested());
    },
    wait: const Duration(milliseconds: 20),
    verify: (b) {
      final s = b.state as PaChatLoaded;
      expect(s.pendingAttachments.map((a) => a.name), <String>['ok.png']);
      expect(s.sendFailure, isA<PaAttachmentTooLargeFailure>());
      verify(
        () => repo.uploadAttachment(
          bytes: any(named: 'bytes'),
          filename: 'ok.png',
        ),
      ).called(1);
      verifyNever(
        () => repo.uploadAttachment(
          bytes: any(named: 'bytes'),
          filename: 'big.png',
        ),
      );
    },
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
    'cambiar de hilo limpia los pendientes (decisión de la superficie)',
    build: build,
    seed: () => PaChatLoaded(
      conversations: <PaConversation>[
        _conv(),
        _conv(id: 'c2'),
      ],
      activeConversation: _conv(),
      messages: const <PaMessage>[],
      sending: false,
      pendingAttachments: const <PaAttachment>[_att],
      pendingThumbnails: <String, Uint8List>{_att.ref: Uint8List(4)},
    ),
    act: (b) => b.add(const PaChatConversationSelected('c2')),
    verify: (b) {
      final s = b.state as PaChatLoaded;
      expect(s.activeConversation.id, 'c2');
      expect(s.pendingAttachments, isEmpty);
      expect(s.pendingThumbnails, isEmpty);
    },
  );

  group('modalityWarning', () {
    PaChatLoaded loaded({
      required List<PaModelOption> models,
      required String selectedModelId,
      required List<PaAttachment> pending,
      String defaultModelId = '',
    }) => PaChatLoaded(
      conversations: <PaConversation>[_conv()],
      activeConversation: _conv(),
      messages: const <PaMessage>[],
      sending: false,
      models: models,
      defaultModelId: defaultModelId,
      selectedModelId: selectedModelId,
      pendingAttachments: pending,
    );

    test('modelo sin visión + imagen pendiente ⇒ aviso', () {
      final s = loaded(
        models: const <PaModelOption>[
          PaModelOption(
            id: 'm3',
            label: 'MiniMax M3',
            imageInput: false,
            pdfInput: false,
          ),
        ],
        selectedModelId: 'm3',
        pending: const <PaAttachment>[_att],
      );
      expect(s.modalityWarning, isNotEmpty);
      expect(s.modalityWarning.toLowerCase(), contains('imágenes'));
    });

    test('flags null (wire viejo) ⇒ sin aviso', () {
      final s = loaded(
        models: const <PaModelOption>[
          PaModelOption(id: 'm3', label: 'MiniMax M3'),
        ],
        selectedModelId: 'm3',
        pending: const <PaAttachment>[_att],
      );
      expect(s.modalityWarning, isEmpty);
    });

    test('modelo con visión ⇒ sin aviso', () {
      final s = loaded(
        models: const <PaModelOption>[
          PaModelOption(
            id: 'g',
            label: 'Gemini',
            imageInput: true,
            pdfInput: true,
          ),
        ],
        selectedModelId: 'g',
        pending: const <PaAttachment>[_att],
      );
      expect(s.modalityWarning, isEmpty);
    });

    test('sin pendientes ⇒ sin aviso', () {
      final s = loaded(
        models: const <PaModelOption>[
          PaModelOption(
            id: 'm3',
            label: 'MiniMax M3',
            imageInput: false,
            pdfInput: false,
          ),
        ],
        selectedModelId: 'm3',
        pending: const <PaAttachment>[],
      );
      expect(s.modalityWarning, isEmpty);
    });
  });
}
