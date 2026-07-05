import 'dart:async';

import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_attachment.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_conversation.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_message.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_models.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_progress.dart';
import 'package:ataulfo/features/platform_agent/domain/repositories/platform_agent_repository.dart';
import 'package:ataulfo/features/platform_agent/presentation/bloc/platform_agent_chat_bloc.dart';
import 'package:ataulfo/features/platform_agent/presentation/pages/platform_agent_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/chat_media_providers.dart';

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

void main() {
  setUpAll(() => registerFallbackValue(Uint8List(0)));

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
  });

  Future<void> pump(
    WidgetTester tester,
    List<PaMessage> msgs, {
    List<PaModelOption> models = const <PaModelOption>[],
    String defaultModelId = '',
  }) async {
    when(() => repo.listModels()).thenAnswer(
      (_) async => PaModels(options: models, defaultId: defaultModelId),
    );
    when(
      () => repo.listMessages(
        conversationId: 'c1',
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async =>
          PaMessagesPage(messages: msgs.reversed.toList(), nextCursor: ''),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: BlocProvider<PlatformAgentChatBloc>(
              create: (_) => PlatformAgentChatBloc(
                repo: repo,
                events: events,
                picker: picker,
              )..add(const PaChatStarted()),
              child: wrapWithChatMedia(const PlatformAgentPage()),
            ),
          ),
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
          bytes: any(named: 'bytes'),
          filename: 'catalogo.png',
        ),
      ).thenAnswer((_) async => _att);

      await pump(tester, <PaMessage>[]);
      expect(find.byKey(const Key('pa.attach')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pa.attach')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('pa.pending_att.tenant/org/media/a1.png')),
        findsOneWidget,
      );
      expect(find.text('catalogo.png'), findsOneWidget);
      expect(
        find.byKey(const Key('pa.pending_thumb.tenant/org/media/a1.png')),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('pa.pending_att.tenant/org/media/a1.png')),
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
          bytes: any(named: 'bytes'),
          filename: 'catalogo.png',
        ),
      ).thenAnswer((_) async => _att);

      await pump(
        tester,
        <PaMessage>[],
        models: const <PaModelOption>[
          PaModelOption(
            id: 'm3',
            label: 'MiniMax M3',
            imageInput: false,
            pdfInput: false,
          ),
        ],
        defaultModelId: 'm3',
      );

      expect(find.byKey(const Key('pa.modality_warning')), findsNothing);
      await tester.tap(find.byKey(const Key('pa.attach')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pa.modality_warning')), findsOneWidget);
    },
  );

  testWidgets(
    'mientras un adjunto sube, Enviar queda deshabilitado (no pierde el lote)',
    (tester) async {
      final gate = Completer<PaAttachment>();
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
      ).thenAnswer((_) => gate.future);

      await pump(tester, <PaMessage>[]);

      await tester.enterText(
        find.byKey(const Key('pa.composer.field')),
        'mira',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('pa.attach')));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('pa.composer.send')));
      await tester.pump();
      verifyNever(
        () => repo.sendMessage(
          conversationId: any(named: 'conversationId'),
          content: any(named: 'content'),
          model: any(named: 'model'),
          attachments: any(named: 'attachments'),
        ),
      );

      gate.complete(_att);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('una burbuja user con adjuntos pinta sus chips', (tester) async {
    await pump(tester, <PaMessage>[
      PaMessage(
        id: 'm1',
        conversationId: 'c1',
        role: 'user',
        content: 'mira',
        attachments: const <PaAttachment>[_att],
        createdAt: DateTime.utc(2026, 6, 10, 10),
      ),
    ]);
    expect(find.text('catalogo.png'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });
}
