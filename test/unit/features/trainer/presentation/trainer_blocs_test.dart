import 'package:ataulfo/features/trainer/domain/entities/preview_item.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_conversation.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_models.dart';
import 'package:ataulfo/features/trainer/domain/entities/workspace_doc.dart';
import 'package:ataulfo/features/trainer/domain/failures/trainer_failure.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/preview_bloc.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/trainer_chat_bloc.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/workspace_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
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

TrainerMessage _msg(String id, String role, String content) => TrainerMessage(
  id: id,
  conversationId: 'c1',
  role: role,
  content: content,
  createdAt: DateTime.utc(2026, 6, 10, 10),
);

final _doc = WorkspaceDoc(
  name: 'menu',
  content: 'Tacos \$25',
  sizeBytes: 9,
  updatedByKind: 'trainer',
  version: 1,
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
);

PreviewItem _item(
  String kind, {
  String text = '',
  String summary = '',
  int delayMs = 0,
}) => PreviewItem(
  kind: kind,
  text: text,
  summary: summary,
  delayMs: delayMs,
  at: DateTime.utc(2026, 6, 10),
);

void main() {
  group('TrainerChatBloc', () {
    late _MockTrainerRepo repo;
    setUp(() => repo = _MockTrainerRepo());

    TrainerChatBloc build() => TrainerChatBloc(repo: repo, templateId: 't1');

    blocTest<TrainerChatBloc, TrainerChatState>(
      'Started: reanuda el hilo más reciente y carga mensajes en ASC',
      build: build,
      setUp: () {
        when(
          () => repo.listConversations(templateId: 't1'),
        ).thenAnswer((_) async => <TrainerConversation>[_conv]);
        when(
          () => repo.listMessages(
            templateId: 't1',
            conversationId: 'c1',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => TrainerMessagesPage(
            // El wire entrega DESC; el bloc invierte a ASC para el hilo.
            messages: <TrainerMessage>[
              _msg('m2', 'assistant', 'te ayudo'),
              _msg('m1', 'user', 'hola'),
            ],
            nextCursor: '',
          ),
        );
      },
      act: (b) => b.add(const TrainerChatStarted()),
      expect: () => <dynamic>[
        const TrainerChatLoading(),
        isA<TrainerChatLoaded>()
            .having((s) => s.conversation.id, 'conv', 'c1')
            .having((s) => s.messages.first.id, 'primero ASC', 'm1')
            .having((s) => s.sending, 'sending', false),
      ],
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'Started sin hilos: crea uno nuevo',
      build: build,
      setUp: () {
        when(
          () => repo.listConversations(templateId: 't1'),
        ).thenAnswer((_) async => <TrainerConversation>[]);
        when(
          () => repo.createConversation(
            templateId: 't1',
            title: any(named: 'title'),
          ),
        ).thenAnswer((_) async => _conv);
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
      },
      act: (b) => b.add(const TrainerChatStarted()),
      verify: (_) {
        verify(
          () => repo.createConversation(
            templateId: 't1',
            title: any(named: 'title'),
          ),
        ).called(1);
      },
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'MessageSent: optimista + typing, luego recarga del server',
      build: build,
      seed: () => TrainerChatLoaded(
        conversation: _conv,
        messages: <TrainerMessage>[_msg('m1', 'user', 'hola')],
        sending: false,
      ),
      setUp: () {
        when(
          () => repo.sendMessage(
            templateId: 't1',
            conversationId: 'c1',
            content: 'mejora el prompt',
          ),
        ).thenAnswer((_) async => _msg('m3', 'assistant', 'hecho'));
        when(
          () => repo.listMessages(
            templateId: 't1',
            conversationId: 'c1',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => TrainerMessagesPage(
            messages: <TrainerMessage>[
              _msg('m3', 'assistant', 'hecho'),
              _msg('m2', 'user', 'mejora el prompt'),
              _msg('m1', 'user', 'hola'),
            ],
            nextCursor: '',
          ),
        );
      },
      act: (b) => b.add(const TrainerChatMessageSent('mejora el prompt')),
      expect: () => <dynamic>[
        isA<TrainerChatLoaded>()
            .having((s) => s.sending, 'typing visible', true)
            .having(
              (s) => s.messages.last.content,
              'optimista',
              'mejora el prompt',
            ),
        isA<TrainerChatLoaded>()
            .having((s) => s.sending, 'sending off', false)
            .having((s) => s.messages.length, 'recargado', 3),
      ],
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'Started carga la allowlist de modelos (best-effort) con el default',
      build: build,
      setUp: () {
        when(
          () => repo.listConversations(templateId: 't1'),
        ).thenAnswer((_) async => <TrainerConversation>[_conv]);
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
      },
      act: (b) => b.add(const TrainerChatStarted()),
      expect: () => <dynamic>[
        const TrainerChatLoading(),
        isA<TrainerChatLoaded>()
            .having((s) => s.models.length, 'allowlist', 3)
            .having((s) => s.defaultModelId, 'default', 'gpt-5.5')
            .having((s) => s.selectedModelId, 'arranca en default', ''),
      ],
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'ModelSelected fija el modelo y MessageSent lo manda al repo',
      build: build,
      seed: () => TrainerChatLoaded(
        conversation: _conv,
        messages: <TrainerMessage>[_msg('m1', 'user', 'hola')],
        sending: false,
        models: const <TrainerModelOption>[
          TrainerModelOption(id: 'MiniMax-M3', label: 'MiniMax M3'),
        ],
      ),
      setUp: () {
        when(
          () => repo.sendMessage(
            templateId: 't1',
            conversationId: 'c1',
            content: 'hola M3',
            model: 'MiniMax-M3',
          ),
        ).thenAnswer((_) async => _msg('m3', 'assistant', 'hecho'));
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
      },
      act: (b) => b
        ..add(const TrainerChatModelSelected('MiniMax-M3'))
        ..add(const TrainerChatMessageSent('hola M3')),
      verify: (_) {
        verify(
          () => repo.sendMessage(
            templateId: 't1',
            conversationId: 'c1',
            content: 'hola M3',
            model: 'MiniMax-M3',
          ),
        ).called(1);
      },
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'ModelSelected("") vuelve al default de la plataforma (sin model)',
      build: build,
      seed: () => TrainerChatLoaded(
        conversation: _conv,
        messages: const <TrainerMessage>[],
        sending: false,
        models: const <TrainerModelOption>[
          TrainerModelOption(id: 'gpt-5.5', label: 'ChatGPT 5.5'),
        ],
        selectedModelId: 'gpt-5.5',
      ),
      setUp: () {
        when(
          () => repo.sendMessage(
            templateId: 't1',
            conversationId: 'c1',
            content: 'x',
          ),
        ).thenAnswer((_) async => _msg('m3', 'assistant', 'ok'));
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
      },
      act: (b) => b
        ..add(const TrainerChatModelSelected(''))
        ..add(const TrainerChatMessageSent('x')),
      verify: (_) {
        verify(
          () => repo.sendMessage(
            templateId: 't1',
            conversationId: 'c1',
            content: 'x',
          ),
        ).called(1);
      },
    );

    blocTest<TrainerChatBloc, TrainerChatState>(
      'MessageSent con motor caído: revierte el optimista y expone el fallo',
      build: build,
      seed: () => TrainerChatLoaded(
        conversation: _conv,
        messages: <TrainerMessage>[_msg('m1', 'user', 'hola')],
        sending: false,
      ),
      setUp: () {
        when(
          () => repo.sendMessage(
            templateId: 't1',
            conversationId: 'c1',
            content: 'x',
          ),
        ).thenThrow(const TrainerEngineFailure());
      },
      act: (b) => b.add(const TrainerChatMessageSent('x')),
      expect: () => <dynamic>[
        isA<TrainerChatLoaded>().having((s) => s.sending, 'typing', true),
        isA<TrainerChatLoaded>()
            .having((s) => s.sending, 'off', false)
            .having((s) => s.messages.length, 'optimista revertido', 1)
            .having(
              (s) => s.sendFailure,
              'fallo expuesto',
              isA<TrainerEngineFailure>(),
            ),
      ],
    );
  });

  group('WorkspaceBloc', () {
    late _MockWorkspaceRepo repo;
    setUp(() => repo = _MockWorkspaceRepo());

    WorkspaceBloc build() => WorkspaceBloc(repo: repo, templateId: 't1');

    blocTest<WorkspaceBloc, WorkspaceState>(
      'Load lista los docs',
      build: build,
      setUp: () {
        when(
          () => repo.listDocs(templateId: 't1'),
        ).thenAnswer((_) async => <WorkspaceDoc>[_doc]);
      },
      act: (b) => b.add(const WorkspaceLoadRequested()),
      expect: () => <dynamic>[
        const WorkspaceLoading(),
        isA<WorkspaceLoaded>().having((s) => s.docs.length, 'docs', 1),
      ],
    );

    blocTest<WorkspaceBloc, WorkspaceState>(
      'Create con 409 (duplicado): expone fallo sin perder el snapshot',
      build: build,
      seed: () => WorkspaceLoaded(docs: <WorkspaceDoc>[_doc], mutating: false),
      setUp: () {
        when(
          () => repo.createDoc(templateId: 't1', name: 'menu', content: 'x'),
        ).thenThrow(const TrainerConflictFailure());
      },
      act: (b) => b.add(const WorkspaceDocCreated(name: 'menu', content: 'x')),
      expect: () => <dynamic>[
        isA<WorkspaceLoaded>().having((s) => s.mutating, 'mutating', true),
        isA<WorkspaceLoaded>()
            .having((s) => s.mutating, 'off', false)
            .having((s) => s.docs.length, 'snapshot intacto', 1)
            .having(
              (s) => s.mutationFailure,
              'fallo',
              isA<TrainerConflictFailure>(),
            ),
      ],
    );

    blocTest<WorkspaceBloc, WorkspaceState>(
      'Update feliz recarga del server',
      build: build,
      seed: () => WorkspaceLoaded(docs: <WorkspaceDoc>[_doc], mutating: false),
      setUp: () {
        when(
          () => repo.updateDoc(
            templateId: 't1',
            name: 'menu',
            content: 'nuevo',
            version: 1,
          ),
        ).thenAnswer((_) async => _doc);
        when(
          () => repo.listDocs(templateId: 't1'),
        ).thenAnswer((_) async => <WorkspaceDoc>[_doc, _doc]);
      },
      act: (b) => b.add(
        const WorkspaceDocUpdated(name: 'menu', content: 'nuevo', version: 1),
      ),
      expect: () => <dynamic>[
        isA<WorkspaceLoaded>().having((s) => s.mutating, 'mutating', true),
        isA<WorkspaceLoaded>()
            .having((s) => s.mutating, 'off', false)
            .having((s) => s.docs.length, 'recargado', 2),
      ],
    );
  });

  group('PreviewBloc', () {
    late _MockPreviewRepo repo;
    late List<Duration> paces;
    setUp(() {
      repo = _MockPreviewRepo();
      paces = <Duration>[];
    });

    // El pacer registra las esperas sin dormir: los tests verifican la
    // CADENCIA pedida, no relojes reales.
    PreviewBloc build() => PreviewBloc(
      repo: repo,
      templateId: 't1',
      pace: (d) async => paces.add(d),
    );

    blocTest<PreviewBloc, PreviewState>(
      'Started rehidrata el transcript vivo',
      build: build,
      setUp: () {
        when(() => repo.transcript(templateId: 't1')).thenAnswer(
          (_) async => PreviewTranscript(
            items: <PreviewItem>[_item('user', text: 'hola')],
          ),
        );
      },
      act: (b) => b.add(const PreviewStarted()),
      expect: () => <dynamic>[
        const PreviewLoading(),
        isA<PreviewLoaded>().having((s) => s.items.length, 'items', 1),
      ],
    );

    blocTest<PreviewBloc, PreviewState>(
      'turno pendiente: pinta el user, anuncia la acumulación sin typing, '
      'pollea al cerrar la ventana y revela el flush con cadencia',
      build: build,
      seed: () => const PreviewLoaded(items: <PreviewItem>[], sending: false),
      setUp: () {
        when(
          () => repo.sendMessage(templateId: 't1', content: 'hola'),
        ).thenAnswer(
          (_) async => PreviewTurn(
            items: <PreviewItem>[_item('user', text: 'hola')],
            iterations: 0,
            pending: true,
            // Vencida ya: el poll arranca de inmediato (sin esperar reloj).
            windowEndsAt: DateTime.utc(2026, 6, 12, 12),
          ),
        );
        when(() => repo.transcript(templateId: 't1')).thenAnswer(
          (_) async => PreviewTranscript(
            items: <PreviewItem>[
              _item('user', text: 'hola'),
              _item('bot', text: 'les respondo todo'),
            ],
          ),
        );
      },
      act: (b) async {
        b.add(const PreviewMessageSent('hola'));
        // El poll corre fuera del handler y cede un timer por iteración:
        // ceder turnos de event loop hasta que el flush aterrice.
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      },
      expect: () => <dynamic>[
        // Optimista mientras el POST viaja.
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'typing', true)
            .having((s) => s.items.length, 'optimista', 1),
        // Acumulando: el user del server reemplaza al optimista, SIN typing
        // (el bot aún no responde) y con la ventana anunciada.
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'sin typing', false)
            .having((s) => s.items.length, 'user del server', 1)
            .having((s) => s.accumulatingUntil, 'ventana', isNotNull),
        // El flush llegó: typing durante el revelado.
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'typing del revelado', true)
            .having((s) => s.accumulatingUntil, 'ventana cerrada', isNull),
        // Revelado completo.
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'off', false)
            .having((s) => s.items.length, 'flush revelado', 2)
            .having((s) => s.items.last.isBot, 'bot', true),
      ],
    );

    blocTest<PreviewBloc, PreviewState>(
      'enviar DURANTE la acumulación se permite (se suma al batch) y el '
      'flush combinado se revela al cerrar la ventana',
      build: build,
      seed: () => PreviewLoaded(
        items: <PreviewItem>[_item('user', text: 'hola')],
        sending: false,
        accumulatingUntil: DateTime.utc(2026, 6, 12, 12, 5),
      ),
      setUp: () {
        when(
          () => repo.sendMessage(templateId: 't1', content: '¿hay envío?'),
        ).thenAnswer(
          (_) async => PreviewTurn(
            items: <PreviewItem>[_item('user', text: '¿hay envío?')],
            iterations: 0,
            pending: true,
            windowEndsAt: DateTime.utc(2026, 6, 12, 12, 5),
          ),
        );
        // El stub del poll DEBE terminar (pending=false): un transcript
        // eternamente pendiente + pacer instantáneo = loop infinito que
        // come memoria hasta el OOM del runner.
        when(() => repo.transcript(templateId: 't1')).thenAnswer(
          (_) async => PreviewTranscript(
            items: <PreviewItem>[
              _item('user', text: 'hola'),
              _item('user', text: '¿hay envío?'),
              _item('bot', text: 'sí hay'),
            ],
          ),
        );
      },
      act: (b) async {
        b.add(const PreviewMessageSent('¿hay envío?'));
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      },
      expect: () => <dynamic>[
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'typing del POST', true)
            .having((s) => s.items.length, 'optimista sumado', 2),
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'sin typing', false)
            .having((s) => s.items.length, 'dos users', 2)
            .having((s) => s.accumulatingUntil, 'ventana viva', isNotNull),
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'typing del revelado', true)
            .having((s) => s.accumulatingUntil, 'ventana cerrada', isNull),
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'off', false)
            .having((s) => s.items.length, 'flush revelado', 3)
            .having((s) => s.items.last.isBot, 'bot al final', true),
      ],
    );

    blocTest<PreviewBloc, PreviewState>(
      'poll que falla persistentemente expone el fallo y apaga la ventana',
      build: build,
      seed: () => const PreviewLoaded(items: <PreviewItem>[], sending: false),
      setUp: () {
        when(
          () => repo.sendMessage(templateId: 't1', content: 'hola'),
        ).thenAnswer(
          (_) async => PreviewTurn(
            items: <PreviewItem>[_item('user', text: 'hola')],
            iterations: 0,
            pending: true,
            windowEndsAt: DateTime.utc(2026, 6, 12, 12),
          ),
        );
        when(
          () => repo.transcript(templateId: 't1'),
        ).thenThrow(const TrainerNetworkFailure());
      },
      act: (b) async {
        b.add(const PreviewMessageSent('hola'));
        for (var i = 0; i < 24; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      },
      expect: () => <dynamic>[
        isA<PreviewLoaded>().having((s) => s.sending, 'typing', true),
        isA<PreviewLoaded>().having(
          (s) => s.accumulatingUntil,
          'ventana',
          isNotNull,
        ),
        isA<PreviewLoaded>()
            .having((s) => s.failure, 'fallo', isA<TrainerNetworkFailure>())
            .having((s) => s.accumulatingUntil, 'ventana apagada', isNull)
            .having((s) => s.items.length, 'user conservado', 1),
      ],
    );

    blocTest<PreviewBloc, PreviewState>(
      'MessageSent pinta la burbuja del usuario de inmediato y el turno '
      'del server la reemplaza sin duplicarla',
      build: build,
      seed: () => const PreviewLoaded(items: <PreviewItem>[], sending: false),
      setUp: () {
        when(
          () => repo.sendMessage(templateId: 't1', content: 'hola'),
        ).thenAnswer(
          (_) async => PreviewTurn(
            items: <PreviewItem>[
              _item('user', text: 'hola'),
              _item('bot', text: '¡Hola!'),
              _item('action', summary: 'Etiquetaría: VIP'),
            ],
            iterations: 2,
          ),
        );
      },
      act: (b) => b.add(const PreviewMessageSent('hola')),
      expect: () => <dynamic>[
        // Optimista: la burbuja del usuario aparece al ENVIAR, no al
        // resolver el turno.
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'typing', true)
            .having((s) => s.items.length, 'optimista pintado', 1)
            .having((s) => s.items.single.isUser, 'es user', true)
            .having((s) => s.items.single.text, 'texto', 'hola'),
        // El turno se REVELA item por item (cadencia de envío real), no de
        // golpe. El user del server reemplaza al optimista (3 items, no 4) y
        // el typing sigue encendido entre revelados.
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'typing sigue', true)
            .having((s) => s.items.length, 'user del server', 1)
            .having((s) => s.items.first.isUser, 'es user', true),
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'typing sigue', true)
            .having((s) => s.items.length, 'bot revelado', 2),
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'off', false)
            .having((s) => s.items.length, 'turno completo', 3),
      ],
      verify: (_) {
        // user: inmediato (sin pace); bot y action: stagger default.
        expect(paces, hasLength(2));
        expect(paces.every((d) => d.inMilliseconds > 0), isTrue);
      },
    );

    blocTest<PreviewBloc, PreviewState>(
      'los items con delayMs pacean el revelado con el retraso del paso '
      '(clamp a 6s)',
      build: build,
      seed: () => const PreviewLoaded(items: <PreviewItem>[], sending: false),
      setUp: () {
        when(
          () => repo.sendMessage(templateId: 't1', content: 'promo'),
        ).thenAnswer(
          (_) async => PreviewTurn(
            items: <PreviewItem>[
              _item('user', text: 'promo'),
              _item('bot', text: 'uno', delayMs: 1500),
              _item('bot', text: 'dos', delayMs: 9000),
            ],
            iterations: 2,
          ),
        );
      },
      act: (b) => b.add(const PreviewMessageSent('promo')),
      skip: 4,
      expect: () => <dynamic>[],
      verify: (_) {
        expect(paces, <Duration>[
          const Duration(milliseconds: 1500),
          const Duration(milliseconds: 6000), // 9s clampeado: demo usable
        ]);
      },
    );

    blocTest<PreviewBloc, PreviewState>(
      'Reset limpia la sesión',
      build: build,
      seed: () => PreviewLoaded(
        items: <PreviewItem>[_item('user', text: 'a')],
        sending: false,
      ),
      setUp: () {
        when(() => repo.reset(templateId: 't1')).thenAnswer((_) async {});
      },
      act: (b) => b.add(const PreviewResetRequested()),
      expect: () => <dynamic>[
        isA<PreviewLoaded>().having((s) => s.items, 'vacío', isEmpty),
      ],
    );

    blocTest<PreviewBloc, PreviewState>(
      '503 sin sandbox expone fallo claro',
      build: build,
      seed: () => const PreviewLoaded(items: <PreviewItem>[], sending: false),
      setUp: () {
        when(
          () => repo.sendMessage(templateId: 't1', content: 'x'),
        ).thenThrow(const TrainerUnavailableFailure());
      },
      act: (b) => b.add(const PreviewMessageSent('x')),
      expect: () => <dynamic>[
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'typing', true)
            .having((s) => s.items.length, 'optimista pintado', 1),
        // El sandbox descarta el item user cuando el turno falla: la
        // burbuja optimista se revierte para espejar la verdad del server.
        isA<PreviewLoaded>()
            .having((s) => s.sending, 'off', false)
            .having((s) => s.items, 'optimista revertido', isEmpty)
            .having(
              (s) => s.failure,
              'fallo',
              isA<TrainerUnavailableFailure>(),
            ),
      ],
    );
  });
}
