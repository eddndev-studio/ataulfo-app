import 'dart:async';

import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_attachment.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_conversation.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_models.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/trainer_chat_bloc.dart';
import 'package:ataulfo/features/trainer/presentation/pages/trainer_chat_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/chat_media_providers.dart';

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
  });

  Future<void> pump(
    WidgetTester tester,
    List<TrainerMessage> msgs, {
    List<TrainerModelOption> models = const <TrainerModelOption>[],
    String defaultModelId = '',
  }) async {
    when(() => repo.listModels(templateId: 't1')).thenAnswer(
      (_) async => TrainerModels(options: models, defaultId: defaultModelId),
    );
    when(
      () => repo.listMessages(
        templateId: 't1',
        conversationId: 'c1',
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async =>
          TrainerMessagesPage(messages: msgs.reversed.toList(), nextCursor: ''),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<TrainerChatBloc>(
          create: (_) =>
              TrainerChatBloc(repo: repo, templateId: 't1', picker: picker)
                ..add(const TrainerChatStarted()),
          child: wrapWithChatMedia(const TrainerChatPage(templateId: 't1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'el clip sube el archivo y pinta el chip pendiente con miniatura y su ✕',
    (tester) async {
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

      await pump(tester, <TrainerMessage>[]);
      expect(find.byKey(const Key('trainer.attach')), findsOneWidget);

      await tester.tap(find.byKey(const Key('trainer.attach')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('trainer.pending_att.tenant/org/media/a1.png')),
        findsOneWidget,
      );
      expect(find.text('catalogo.png'), findsOneWidget);
      // Miniatura real del pendiente (bytes locales, sin red).
      expect(
        find.byKey(const Key('trainer.pending_thumb.tenant/org/media/a1.png')),
        findsOneWidget,
      );

      // El ✕ del chip lo quita.
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('trainer.pending_att.tenant/org/media/a1.png')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'un modelo sin visión con imagen pendiente muestra el aviso de modalidad',
    (tester) async {
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

      await pump(
        tester,
        <TrainerMessage>[],
        models: const <TrainerModelOption>[
          TrainerModelOption(
            id: 'm3',
            label: 'MiniMax M3',
            imageInput: false,
            pdfInput: false,
          ),
        ],
        defaultModelId: 'm3',
      );

      expect(find.byKey(const Key('trainer.modality_warning')), findsNothing);
      await tester.tap(find.byKey(const Key('trainer.attach')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trainer.modality_warning')), findsOneWidget);
    },
  );

  testWidgets(
    'mientras un adjunto sube, Enviar queda deshabilitado (no pierde el lote)',
    (tester) async {
      final gate = Completer<TrainerAttachment>();
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
      ).thenAnswer((_) => gate.future);

      await pump(tester, <TrainerMessage>[]);

      // Escribe ANTES de adjuntar (con el composer aún habilitado).
      await tester.enterText(
        find.byKey(const Key('trainer.composer.field')),
        'mira',
      );
      await tester.pump();

      // Adjunta: la subida queda retenida en el gate ⇒ attaching=true.
      await tester.tap(find.byKey(const Key('trainer.attach')));
      await tester.pump();
      await tester.pump();

      // Con el lote a medio subir, tocar Enviar no despacha el turno.
      await tester.tap(find.byKey(const Key('trainer.composer.send')));
      await tester.pump();
      verifyNever(
        () => repo.sendMessage(
          templateId: any(named: 'templateId'),
          conversationId: any(named: 'conversationId'),
          content: any(named: 'content'),
          model: any(named: 'model'),
          attachments: any(named: 'attachments'),
        ),
      );

      // Cierra el gate para no dejar el future colgado.
      gate.complete(_att);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('una burbuja user con adjuntos pinta sus chips', (tester) async {
    await pump(tester, <TrainerMessage>[
      TrainerMessage(
        id: 'm1',
        conversationId: 'c1',
        role: 'user',
        content: 'mira',
        attachments: const <TrainerAttachment>[_att],
        createdAt: DateTime.utc(2026, 6, 10, 10),
      ),
    ]);
    expect(find.text('catalogo.png'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });
}
