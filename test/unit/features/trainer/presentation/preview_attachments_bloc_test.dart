import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/trainer/domain/entities/preview_attachment.dart';
import 'package:ataulfo/features/trainer/domain/entities/preview_item.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/preview_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPreviewRepo extends Mock implements PreviewRepository {}

class _MockPicker extends Mock implements MediaFilePicker {}

void main() {
  late _MockPreviewRepo repo;
  late _MockPicker picker;

  setUp(() {
    repo = _MockPreviewRepo();
    picker = _MockPicker();
    when(
      () => repo.transcript(templateId: 't1'),
    ).thenAnswer((_) async => const PreviewTranscript(items: <PreviewItem>[]));
  });

  PreviewBloc build() =>
      PreviewBloc(repo: repo, templateId: 't1', picker: picker);

  blocTest<PreviewBloc, PreviewState>(
    'adjuntar guarda los bytes en pendientes (sin red)',
    build: build,
    setUp: () {
      when(() => picker.pick()).thenAnswer(
        (_) async => PickedMedia(
          bytes: Uint8List.fromList(<int>[1, 2]),
          filename: 'foto.png',
        ),
      );
    },
    act: (b) async {
      b.add(const PreviewStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const PreviewAttachRequested());
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      final s = b.state as PreviewLoaded;
      expect(s.pendingAttachments.single.name, 'foto.png');
    },
  );

  blocTest<PreviewBloc, PreviewState>(
    'enviar manda los adjuntos y los limpia',
    build: build,
    setUp: () {
      when(() => picker.pick()).thenAnswer(
        (_) async => PickedMedia(
          bytes: Uint8List.fromList(<int>[1, 2]),
          filename: 'foto.png',
        ),
      );
      when(
        () => repo.sendMessage(
          templateId: 't1',
          content: 'mira',
          attachments: any(named: 'attachments'),
        ),
      ).thenAnswer(
        (_) async => PreviewTurn(
          items: <PreviewItem>[
            PreviewItem(kind: 'user', text: 'mira', at: DateTime.utc(2026)),
            PreviewItem(kind: 'bot', text: 'ok', at: DateTime.utc(2026)),
          ],
          iterations: 1,
        ),
      );
    },
    act: (b) async {
      b.add(const PreviewStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const PreviewAttachRequested());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      b.add(const PreviewMessageSent('mira'));
    },
    wait: const Duration(milliseconds: 50),
    verify: (b) {
      final s = b.state as PreviewLoaded;
      expect(s.pendingAttachments, isEmpty);
      final sent =
          verify(
                () => repo.sendMessage(
                  templateId: 't1',
                  content: 'mira',
                  attachments: captureAny(named: 'attachments'),
                ),
              ).captured.single
              as List<PreviewAttachment>;
      expect(sent.single.name, 'foto.png');
    },
  );

  blocTest<PreviewBloc, PreviewState>(
    'quitar un adjunto pendiente por nombre',
    build: build,
    setUp: () {
      when(() => picker.pick()).thenAnswer(
        (_) async => PickedMedia(
          bytes: Uint8List.fromList(<int>[1, 2]),
          filename: 'foto.png',
        ),
      );
    },
    act: (b) async {
      b.add(const PreviewStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const PreviewAttachRequested());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      b.add(const PreviewAttachmentRemoved('foto.png'));
    },
    wait: const Duration(milliseconds: 10),
    verify: (b) {
      expect((b.state as PreviewLoaded).pendingAttachments, isEmpty);
    },
  );
}
