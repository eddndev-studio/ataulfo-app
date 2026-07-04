import 'dart:async';

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

TrainerAttachment _imgFor(String name) => TrainerAttachment(
  ref: 'ref/$name',
  mime: 'image/png',
  name: name,
  sizeBytes: 4,
);

TrainerMessage _assistant() => TrainerMessage(
  id: 'mx',
  conversationId: 'c1',
  role: 'assistant',
  content: 'ya',
  createdAt: DateTime.utc(2026, 6, 10, 10),
);

void main() {
  setUpAll(() => registerFallbackValue(Uint8List(0)));

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

  // Reproduce la carrera adjuntar-mientras-envía: con el lote a medio subir
  // (attaching=true, primer archivo ya pendiente), un envío NO debe colarse.
  // Antes del fix, `_onMessageSent` capturaba el estado stale y, al resolver
  // el POST, limpiaba los pendientes pisando los archivos que seguían subiendo:
  // b y c quedaban en storage huérfanos y desaparecían de la UI sin aviso.
  blocTest<TrainerChatBloc, TrainerChatState>(
    'enviar mientras un lote sube es no-op: no manda ni pierde adjuntos',
    build: build,
    setUp: () {
      when(() => picker.pickMultiple()).thenAnswer(
        (_) async => <PickedMedia>[
          PickedMedia(bytes: Uint8List(4), filename: 'a.png'),
          PickedMedia(bytes: Uint8List(4), filename: 'b.png'),
          PickedMedia(bytes: Uint8List(4), filename: 'c.png'),
        ],
      );
      // El primer archivo sube de inmediato; el resto queda retenido en el gate
      // para mantener la ventana attaching=true abierta durante el envío.
      final gate = Completer<void>();
      when(
        () => repo.uploadAttachment(
          templateId: 't1',
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      ).thenAnswer((inv) async {
        final name = inv.namedArguments[#filename] as String;
        if (name != 'a.png') await gate.future;
        return _imgFor(name);
      });
      // Si el envío se colara (bug), el POST resolvería y limpiaría pendientes.
      when(
        () => repo.sendMessage(
          templateId: 't1',
          conversationId: 'c1',
          content: any(named: 'content'),
          model: any(named: 'model'),
          attachments: any(named: 'attachments'),
        ),
      ).thenAnswer((_) async => _assistant());
      // Guardar la referencia al gate para cerrarlo desde act.
      _gates['race'] = gate;
    },
    act: (b) async {
      b.add(const TrainerChatStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const TrainerChatAttachRequested());
      // Deja que suba el primero y quede parado en b (attaching sigue true).
      await Future<void>.delayed(const Duration(milliseconds: 5));
      b.add(const TrainerChatMessageSent('mira'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      _gates['race']!.complete(); // libera b y c
      await Future<void>.delayed(const Duration(milliseconds: 5));
    },
    wait: const Duration(milliseconds: 30),
    verify: (b) {
      final s = b.state as TrainerChatLoaded;
      // El envío no viajó mientras subía el lote.
      verifyNever(
        () => repo.sendMessage(
          templateId: any(named: 'templateId'),
          conversationId: any(named: 'conversationId'),
          content: any(named: 'content'),
          model: any(named: 'model'),
          attachments: any(named: 'attachments'),
        ),
      );
      // Los tres adjuntos siguen pendientes: ninguno se perdió en storage.
      expect(s.pendingAttachments.map((a) => a.name), <String>[
        'a.png',
        'b.png',
        'c.png',
      ]);
      expect(s.attaching, isFalse);
    },
  );
}

/// Gates compartidos entre `setUp` y `act` de un mismo `blocTest` (no hay otro
/// canal para pasarlos, y cada caso usa su propia clave).
final Map<String, Completer<void>> _gates = <String, Completer<void>>{};
