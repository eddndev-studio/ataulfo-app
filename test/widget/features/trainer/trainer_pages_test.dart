import 'package:ataulfo/core/design/widgets/app_chat_composer.dart';
import 'package:ataulfo/features/trainer/domain/entities/preview_item.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_conversation.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_models.dart';
import 'package:ataulfo/features/trainer/domain/entities/workspace_doc.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/preview_bloc.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/trainer_chat_bloc.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/workspace_bloc.dart';
import 'package:ataulfo/features/trainer/presentation/pages/preview_page.dart';
import 'package:ataulfo/features/trainer/presentation/pages/trainer_chat_page.dart';
import 'package:ataulfo/features/trainer/presentation/pages/workspace_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrainerRepo extends Mock implements TrainerRepository {}

class _MockWorkspaceRepo extends Mock implements WorkspaceRepository {}

class _MockPreviewRepo extends Mock implements PreviewRepository {}

final _conv = TrainerConversation(
  id: 'c1',
  templateId: 't1',
  title: 'Entrenamiento',
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

TrainerMessage _msg(
  String id,
  String role,
  String content, {
  String? toolResultsRaw,
}) => TrainerMessage(
  id: id,
  conversationId: 'c1',
  role: role,
  content: content,
  toolResultsRaw: toolResultsRaw,
  createdAt: DateTime.utc(2026, 6, 10, 10),
);

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('TrainerChatPage', () {
    late _MockTrainerRepo repo;
    setUp(() {
      repo = _MockTrainerRepo();
      when(
        () => repo.listConversations(templateId: 't1'),
      ).thenAnswer((_) async => <TrainerConversation>[_conv]);
    });

    Future<void> pump(WidgetTester tester, List<TrainerMessage> msgs) async {
      when(
        () => repo.listMessages(
          templateId: 't1',
          conversationId: 'c1',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => TrainerMessagesPage(
          messages: msgs.reversed.toList(),
          nextCursor: '',
        ),
      );
      await tester.pumpWidget(
        _wrap(
          BlocProvider<TrainerChatBloc>(
            create: (_) =>
                TrainerChatBloc(repo: repo, templateId: 't1')
                  ..add(const TrainerChatStarted()),
            child: const TrainerChatPage(templateId: 't1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renderiza burbujas y la tarjeta de cambio de edit_prompt', (
      tester,
    ) async {
      await pump(tester, <TrainerMessage>[
        _msg('m1', 'user', 'mejora el tono'),
        _msg(
          'm2',
          'tool',
          '',
          toolResultsRaw:
              '{"toolName":"edit_prompt","content":"{\\"status\\":\\"updated\\"}"}',
        ),
        _msg('m3', 'assistant', 'listo, tono cálido'),
      ]);

      expect(find.text('mejora el tono'), findsOneWidget);
      expect(find.text('listo, tono cálido'), findsOneWidget);
      expect(find.byKey(const Key('trainer.change_card.m2')), findsOneWidget);
      expect(find.textContaining('Prompt actualizado'), findsOneWidget);
    });

    testWidgets('hilo nuevo muestra chips de arranque y mandan el mensaje', (
      tester,
    ) async {
      await pump(tester, <TrainerMessage>[]);
      expect(find.byKey(const Key('trainer.chip.0')), findsOneWidget);

      when(
        () => repo.sendMessage(
          templateId: 't1',
          conversationId: 'c1',
          content: any(named: 'content'),
          attachments: any(named: 'attachments'),
        ),
      ).thenAnswer((_) async => _msg('mx', 'assistant', 'ok'));

      await tester.tap(find.byKey(const Key('trainer.chip.0')));
      await tester.pump();
      verify(
        () => repo.sendMessage(
          templateId: 't1',
          conversationId: 'c1',
          content: any(named: 'content'),
          attachments: any(named: 'attachments'),
        ),
      ).called(1);
      await tester.pumpAndSettle();
    });

    testWidgets('hilo vacío muestra un tip de fondo que orienta al usuario', (
      tester,
    ) async {
      await pump(tester, <TrainerMessage>[]);
      expect(find.byKey(const Key('trainer.empty_hint')), findsOneWidget);
    });

    testWidgets('con mensajes en el hilo NO se muestra el tip de fondo', (
      tester,
    ) async {
      await pump(tester, <TrainerMessage>[_msg('m1', 'user', 'hola')]);
      expect(find.byKey(const Key('trainer.empty_hint')), findsNothing);
    });

    testWidgets('composer manda el texto y bloquea mientras envía', (
      tester,
    ) async {
      await pump(tester, <TrainerMessage>[_msg('m1', 'user', 'hola')]);
      when(
        () => repo.sendMessage(
          templateId: 't1',
          conversationId: 'c1',
          content: 'sube precios',
          attachments: any(named: 'attachments'),
        ),
      ).thenAnswer((_) async => _msg('mx', 'assistant', 'ok'));

      await tester.enterText(
        find.byKey(const Key('trainer.composer.field')),
        'sube precios',
      );
      await tester.pump(); // el botón de enviar se habilita al haber texto
      await tester.tap(find.byKey(const Key('trainer.composer.send')));
      await tester.pump();
      verify(
        () => repo.sendMessage(
          templateId: 't1',
          conversationId: 'c1',
          content: 'sube precios',
          attachments: any(named: 'attachments'),
        ),
      ).called(1);
      await tester.pumpAndSettle();
    });

    testWidgets('el composer es el del design system', (tester) async {
      await pump(tester, <TrainerMessage>[]);
      expect(find.byType(AppChatComposer), findsOneWidget);
    });

    testWidgets('sin allowlist de modelos el selector se oculta', (
      tester,
    ) async {
      await pump(tester, <TrainerMessage>[]);
      expect(find.byKey(const Key('trainer.model.button')), findsNothing);
    });

    testWidgets('elegir un modelo del selector lo manda en el turno', (
      tester,
    ) async {
      when(() => repo.listModels(templateId: 't1')).thenAnswer(
        (_) async => const TrainerModels(
          options: <TrainerModelOption>[
            TrainerModelOption(
              id: 'gemini-3.1-pro-preview',
              label: 'Gemini 3.1 Pro',
            ),
            TrainerModelOption(id: 'gpt-5.5', label: 'ChatGPT 5.5'),
            TrainerModelOption(id: 'MiniMax-M3', label: 'MiniMax M3'),
          ],
          defaultId: 'gpt-5.5',
        ),
      );
      await pump(tester, <TrainerMessage>[_msg('m1', 'user', 'hola')]);

      await tester.tap(find.byKey(const Key('trainer.model.button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('trainer.model.option.MiniMax-M3')),
      );
      await tester.pumpAndSettle();

      when(
        () => repo.sendMessage(
          templateId: 't1',
          conversationId: 'c1',
          content: 'hola M3',
          model: 'MiniMax-M3',
          attachments: any(named: 'attachments'),
        ),
      ).thenAnswer((_) async => _msg('mx', 'assistant', 'ok'));

      await tester.enterText(
        find.byKey(const Key('trainer.composer.field')),
        'hola M3',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('trainer.composer.send')));
      await tester.pump();

      verify(
        () => repo.sendMessage(
          templateId: 't1',
          conversationId: 'c1',
          content: 'hola M3',
          model: 'MiniMax-M3',
          attachments: any(named: 'attachments'),
        ),
      ).called(1);
      await tester.pumpAndSettle();
    });
  });

  group('WorkspacePage', () {
    testWidgets('lista docs con badge del entrenador y abre el editor', (
      tester,
    ) async {
      final repo = _MockWorkspaceRepo();
      when(() => repo.listDocs(templateId: 't1')).thenAnswer(
        (_) async => <WorkspaceDoc>[
          WorkspaceDoc(
            name: 'menu-precios',
            content: '',
            sizeBytes: 120,
            updatedByKind: 'trainer',
            version: 2,
            createdAt: DateTime.utc(2026, 6, 10),
            updatedAt: DateTime.utc(2026, 6, 10),
          ),
        ],
      );
      when(
        () => repo.getDoc(templateId: 't1', name: 'menu-precios'),
      ).thenAnswer(
        (_) async => WorkspaceDoc(
          name: 'menu-precios',
          content: 'Tacos \$25',
          sizeBytes: 9,
          updatedByKind: 'trainer',
          version: 2,
          createdAt: DateTime.utc(2026, 6, 10),
          updatedAt: DateTime.utc(2026, 6, 10),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          RepositoryProvider<WorkspaceRepository>.value(
            value: repo,
            child: BlocProvider<WorkspaceBloc>(
              create: (_) =>
                  WorkspaceBloc(repo: repo, templateId: 't1')
                    ..add(const WorkspaceLoadRequested()),
              child: const WorkspacePage(templateId: 't1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('workspace.doc.menu-precios')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('workspace.badge.menu-precios')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('workspace.doc.menu-precios')));
      await tester.pumpAndSettle();
      expect(find.text('Tacos \$25'), findsOneWidget);
    });
  });

  group('PreviewPage', () {
    testWidgets('banner demo + chips de acciones grabadas + composer', (
      tester,
    ) async {
      final repo = _MockPreviewRepo();
      when(() => repo.transcript(templateId: 't1')).thenAnswer(
        (_) async => PreviewTranscript(
          items: <PreviewItem>[
            PreviewItem(kind: 'user', text: 'hola', at: DateTime.utc(2026)),
            PreviewItem(kind: 'bot', text: '¡Hola!', at: DateTime.utc(2026)),
            PreviewItem(
              kind: 'action',
              tool: 'apply_label',
              summary: 'Etiquetaría el chat: VIP',
              at: DateTime.utc(2026),
            ),
            PreviewItem(
              kind: 'media',
              text: 'mira el catálogo',
              mediaRef: 'ref-7',
              stepType: 'IMAGE',
              at: DateTime.utc(2026),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        _wrap(
          BlocProvider<PreviewBloc>(
            create: (_) =>
                PreviewBloc(repo: repo, templateId: 't1')
                  ..add(const PreviewStarted()),
            child: const PreviewPage(templateId: 't1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('preview.banner')), findsOneWidget);
      expect(find.text('¡Hola!'), findsOneWidget);
      expect(find.textContaining('Etiquetaría el chat: VIP'), findsOneWidget);
      // El paso media del flujo simulado se ve como burbuja de archivo:
      // tipo legible + caption (no un texto plano ni un item invisible).
      expect(find.byKey(const Key('preview.media_bubble')), findsOneWidget);
      expect(find.text('Imagen'), findsOneWidget);
      expect(find.text('mira el catálogo'), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);

      when(
        () => repo.sendMessage(templateId: 't1', content: '¿precio?'),
      ).thenAnswer(
        (_) async => const PreviewTurn(items: <PreviewItem>[], iterations: 1),
      );
      await tester.enterText(
        find.byKey(const Key('preview.composer.field')),
        '¿precio?',
      );
      await tester.pump(); // el botón de enviar se habilita al haber texto
      await tester.tap(find.byKey(const Key('preview.composer.send')));
      await tester.pump();
      verify(
        () => repo.sendMessage(templateId: 't1', content: '¿precio?'),
      ).called(1);
      await tester.pumpAndSettle();

      // El composer es el del design system, como en el resto de la app.
      expect(find.byType(AppChatComposer), findsOneWidget);
    });

    testWidgets(
      'ventana de acumulación: banner visible, composer habilitado, y al '
      'aterrizar el flush el banner se apaga',
      (tester) async {
        final repo = _MockPreviewRepo();
        var polls = 0;
        // 1ª lectura (rehidratar): ventana viva ⇒ banner + poll en marcha.
        // Lecturas siguientes (el poll): flush aterrizado ⇒ banner fuera.
        // El stub DEBE terminar en pending=false o el poll quedaría vivo
        // (timers pendientes rompen el test y comen memoria).
        when(() => repo.transcript(templateId: 't1')).thenAnswer((_) async {
          polls++;
          final user = PreviewItem(
            kind: 'user',
            text: 'hola',
            at: DateTime.utc(2026),
          );
          if (polls == 1) {
            return PreviewTranscript(
              items: <PreviewItem>[user],
              pending: true,
              windowEndsAt: DateTime.utc(2026),
            );
          }
          return PreviewTranscript(
            items: <PreviewItem>[
              user,
              PreviewItem(kind: 'bot', text: 'listo', at: DateTime.utc(2026)),
            ],
          );
        });

        await tester.pumpWidget(
          _wrap(
            BlocProvider<PreviewBloc>(
              create: (_) =>
                  PreviewBloc(repo: repo, templateId: 't1')
                    ..add(const PreviewStarted()),
              child: const PreviewPage(templateId: 't1'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Ventana viva: el banner anuncia la acumulación, SIN typing (el bot
        // aún no responde) y el composer sigue habilitado (se puede seguir
        // mandando — se suma al batch).
        expect(find.byKey(const Key('preview.accumulating')), findsOneWidget);
        expect(find.byKey(const Key('preview.typing')), findsNothing);
        final field = tester.widget<AppChatComposer>(
          find.byType(AppChatComposer),
        );
        expect(field.enabled, isTrue);

        // El poll (cadencia ~1.5s) encuentra el flush: banner fuera, la
        // respuesta del bot en el hilo.
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('preview.accumulating')), findsNothing);
        expect(find.text('listo'), findsOneWidget);
      },
    );

    testWidgets('una acción de error del flush se pinta como chip de fallo', (
      tester,
    ) async {
      final repo = _MockPreviewRepo();
      when(() => repo.transcript(templateId: 't1')).thenAnswer(
        (_) async => PreviewTranscript(
          items: <PreviewItem>[
            PreviewItem(
              kind: 'action',
              tool: 'error',
              summary: 'La corrida del motor falló: timeout',
              at: DateTime.utc(2026),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        _wrap(
          BlocProvider<PreviewBloc>(
            create: (_) =>
                PreviewBloc(repo: repo, templateId: 't1')
                  ..add(const PreviewStarted()),
            child: const PreviewPage(templateId: 't1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('La corrida del motor falló'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
