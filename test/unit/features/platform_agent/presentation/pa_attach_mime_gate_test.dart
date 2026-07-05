import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_attachment.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_conversation.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_message.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_models.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_progress.dart';
import 'package:ataulfo/features/platform_agent/domain/failures/pa_failure.dart';
import 'package:ataulfo/features/platform_agent/domain/repositories/platform_agent_repository.dart';
import 'package:ataulfo/features/platform_agent/presentation/bloc/platform_agent_chat_bloc.dart';
import 'package:ataulfo/features/platform_agent/presentation/widgets/pa_failure_copy.dart';
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

const _mp4 = PaAttachment(
  ref: 'tenant/org/media/v1.mp4',
  mime: 'video/mp4',
  name: 'demo.mp4',
  sizeBytes: 4,
);

const _png = PaAttachment(
  ref: 'tenant/org/media/a1.png',
  mime: 'image/png',
  name: 'catalogo.png',
  sizeBytes: 4,
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
          bytes: any(named: 'bytes'),
          filename: 'demo.MP4',
        ),
      ).thenAnswer((_) async => _mp4);
    },
    act: (b) async {
      b.add(const PaChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const PaChatAttachRequested());
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      final s = b.state as PaChatLoaded;
      expect(s.pendingAttachments, <PaAttachment>[_mp4]);
      expect(s.attaching, isFalse);
      expect(s.sendFailure, isNull);
      // Sin miniatura local: solo las imágenes la siembran.
      expect(s.pendingThumbnails[_mp4.ref], isNull);
    },
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
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
      b.add(const PaChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const PaChatAttachRequested());
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      final s = b.state as PaChatLoaded;
      expect(s.pendingAttachments, isEmpty);
      expect(s.sendFailure, const PaAttachmentUnsupportedFailure());
      expect(s.attaching, isFalse);
      verifyNever(
        () => repo.uploadAttachment(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      );
    },
  );

  blocTest<PlatformAgentChatBloc, PaChatState>(
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
          bytes: any(named: 'bytes'),
          filename: 'catalogo.png',
        ),
      ).thenAnswer((_) async => _png);
    },
    act: (b) async {
      b.add(const PaChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const PaChatAttachRequested());
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      final s = b.state as PaChatLoaded;
      expect(s.pendingAttachments, <PaAttachment>[_png]);
      expect(s.sendFailure, const PaAttachmentUnsupportedFailure());
      expect(s.attaching, isFalse);
      verifyNever(
        () => repo.uploadAttachment(
          bytes: any(named: 'bytes'),
          filename: 'nota.mp3',
        ),
      );
    },
  );

  test('copy de tipo no soportado menciona video', () {
    expect(
      platformAgentFailureCopy(const PaAttachmentUnsupportedFailure()),
      'Tipo no soportado (imagen JPG/PNG/WebP, video MP4 o PDF).',
    );
  });
}
