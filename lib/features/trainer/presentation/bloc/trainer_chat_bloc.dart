import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/trainer_attachment.dart';
import '../../domain/entities/trainer_conversation.dart';
import '../../domain/entities/trainer_message.dart';
import '../../domain/entities/trainer_models.dart';
import '../../domain/entities/trainer_progress.dart';
import '../../domain/failures/trainer_failure.dart';
import '../../../media/domain/repositories/media_file_picker.dart';
import '../../domain/repositories/trainer_repositories.dart';

/// Página de historial que el chat carga por turno. El POST síncrono ya
/// devuelve el assistant final, pero el hilo completo (tool results para
/// las tarjetas de cambio) vive en el server: tras cada turno se RECARGA.
const int _pageLimit = 50;

sealed class TrainerChatEvent {
  const TrainerChatEvent();
}

final class TrainerChatStarted extends TrainerChatEvent {
  const TrainerChatStarted();
}

final class TrainerChatMessageSent extends TrainerChatEvent {
  const TrainerChatMessageSent(this.content);

  final String content;

  @override
  bool operator ==(Object other) =>
      other is TrainerChatMessageSent && other.content == content;

  @override
  int get hashCode => content.hashCode;
}

final class TrainerChatNewConversationRequested extends TrainerChatEvent {
  const TrainerChatNewConversationRequested();
}

/// El operador elige otro hilo del selector.
final class TrainerChatConversationSelected extends TrainerChatEvent {
  const TrainerChatConversationSelected(this.id);

  final String id;

  @override
  bool operator ==(Object other) =>
      other is TrainerChatConversationSelected && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// El operador elige el modelo del entrenador para los próximos turnos.
/// id vacío ⇒ volver al default de la plataforma (el turno viaja sin model).
/// El operador quiere adjuntar un archivo al turno: abre el picker y, si
/// elige, lo sube al hilo (la ref queda PENDIENTE hasta el send).
final class TrainerChatAttachRequested extends TrainerChatEvent {
  const TrainerChatAttachRequested();
}

/// Quita un adjunto pendiente (por ref) antes de enviar.
final class TrainerChatAttachmentRemoved extends TrainerChatEvent {
  const TrainerChatAttachmentRemoved(this.ref);

  final String ref;
}

final class TrainerChatModelSelected extends TrainerChatEvent {
  const TrainerChatModelSelected(this.modelId);

  final String modelId;

  @override
  bool operator ==(Object other) =>
      other is TrainerChatModelSelected && other.modelId == modelId;

  @override
  int get hashCode => modelId.hashCode;
}

/// El operador detiene el turno en vuelo: aborta el POST y revierte el optimista.
final class TrainerChatTurnCancelRequested extends TrainerChatEvent {
  const TrainerChatTurnCancelRequested();
}

/// El composer cambió: persiste el borrador del hilo activo (sin re-emitir por
/// tecla; el borrador se siembra al cambiar de hilo).
final class TrainerChatDraftChanged extends TrainerChatEvent {
  const TrainerChatDraftChanged(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is TrainerChatDraftChanged && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// Progreso en vivo del turno recibido por SSE. Lo emite la suscripción
/// per-turn; el handler lo traduce a la etiqueta del indicador
/// ("Pensando…/Usando {tool}…"). Cosmético: nunca toca el contenido del hilo.
final class TrainerChatProgressReceived extends TrainerChatEvent {
  const TrainerChatProgressReceived(this.event);

  final TrainerProgressEvent event;
}

sealed class TrainerChatState {
  const TrainerChatState();
}

final class TrainerChatLoading extends TrainerChatState {
  const TrainerChatLoading();

  @override
  bool operator ==(Object other) => other is TrainerChatLoading;

  @override
  int get hashCode => (TrainerChatLoading).hashCode;
}

final class TrainerChatFailed extends TrainerChatState {
  const TrainerChatFailed(this.failure);

  final TrainerFailure failure;

  @override
  bool operator ==(Object other) =>
      other is TrainerChatFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

final class TrainerChatLoaded extends TrainerChatState {
  const TrainerChatLoaded({
    required this.conversation,
    required this.messages,
    required this.sending,
    this.conversations = const <TrainerConversation>[],
    this.liveProgress = '',
    this.sendFailure,
    this.models = const <TrainerModelOption>[],
    this.defaultModelId = '',
    this.selectedModelId = '',
    this.pendingAttachments = const <TrainerAttachment>[],
    this.attaching = false,
    this.lastAttemptedContent = '',
    this.draft = '',
  });

  final TrainerConversation conversation;

  /// Conversaciones del entrenamiento (DESC por updatedAt) para el selector de
  /// hilos. La activa es `conversation`.
  final List<TrainerConversation> conversations;

  /// Hilo en orden cronológico ASC (listo para render).
  final List<TrainerMessage> messages;

  /// true mientras el turno viaja (composer bloqueado + typing indicator).
  final bool sending;

  /// Etiqueta del indicador en vivo del turno ("Pensando…/Usando {tool}…"),
  /// alimentada por SSE. '' cuando no hay turno o el progreso aún no llega.
  final String liveProgress;

  /// Fallo del ÚLTIMO turno (el hilo sigue usable); null si no hubo.
  final TrainerFailure? sendFailure;

  /// Allowlist de modelos del entrenador (best-effort: vacía oculta el
  /// selector — backend sin la ruta o fallo de carga).
  final List<TrainerModelOption> models;

  /// Modelo default de la plataforma (informativo, para marcarlo en el menú).
  final String defaultModelId;

  /// Elección vigente del operador; '' = default (el turno viaja sin model).
  final String selectedModelId;

  /// Adjuntos YA subidos esperando el próximo send (chips en el composer).
  final List<TrainerAttachment> pendingAttachments;

  /// true mientras un adjunto sube (el clip muestra spinner).
  final bool attaching;

  /// Texto del último turno enviado, conservado al fallar para que "Reintentar"
  /// lo re-despache y el composer lo recupere. '' si no hay nada que reintentar.
  final String lastAttemptedContent;

  /// Borrador del composer del hilo activo; se siembra al cambiar de hilo o al
  /// cancelar (la persistencia por-hilo vive en el bloc, en memoria).
  final String draft;

  TrainerChatLoaded copyWith({
    TrainerConversation? conversation,
    List<TrainerConversation>? conversations,
    List<TrainerMessage>? messages,
    bool? sending,
    String? liveProgress,
    TrainerFailure? sendFailure,
    bool clearSendFailure = false,
    String? selectedModelId,
    List<TrainerAttachment>? pendingAttachments,
    bool? attaching,
    String? lastAttemptedContent,
    String? draft,
  }) => TrainerChatLoaded(
    conversation: conversation ?? this.conversation,
    conversations: conversations ?? this.conversations,
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    liveProgress: liveProgress ?? this.liveProgress,
    sendFailure: clearSendFailure ? null : (sendFailure ?? this.sendFailure),
    models: models,
    defaultModelId: defaultModelId,
    selectedModelId: selectedModelId ?? this.selectedModelId,
    pendingAttachments: pendingAttachments ?? this.pendingAttachments,
    attaching: attaching ?? this.attaching,
    lastAttemptedContent: lastAttemptedContent ?? this.lastAttemptedContent,
    draft: draft ?? this.draft,
  );

  @override
  bool operator ==(Object other) =>
      other is TrainerChatLoaded &&
      other.conversation == conversation &&
      listEquals(other.conversations, conversations) &&
      listEquals(other.messages, messages) &&
      other.sending == sending &&
      other.liveProgress == liveProgress &&
      other.sendFailure == sendFailure &&
      listEquals(other.models, models) &&
      other.defaultModelId == defaultModelId &&
      other.selectedModelId == selectedModelId &&
      listEquals(other.pendingAttachments, pendingAttachments) &&
      other.attaching == attaching &&
      other.lastAttemptedContent == lastAttemptedContent &&
      other.draft == draft;

  @override
  int get hashCode => Object.hash(
    conversation,
    Object.hashAll(conversations),
    Object.hashAll(messages),
    sending,
    liveProgress,
    sendFailure,
    Object.hashAll(models),
    defaultModelId,
    selectedModelId,
    Object.hashAll(pendingAttachments),
    attaching,
    lastAttemptedContent,
    draft,
  );
}

class TrainerChatBloc extends Bloc<TrainerChatEvent, TrainerChatState> {
  TrainerChatBloc({
    required TrainerRepository repo,
    required String templateId,
    MediaFilePicker? picker,
    TrainerEvents? events,
  }) : _repo = repo,
       _templateId = templateId,
       _picker = picker,
       _events = events,
       super(const TrainerChatLoading()) {
    on<TrainerChatStarted>(_onStarted);
    on<TrainerChatMessageSent>(_onMessageSent);
    on<TrainerChatAttachRequested>(_onAttachRequested);
    on<TrainerChatAttachmentRemoved>(_onAttachmentRemoved);
    on<TrainerChatNewConversationRequested>(_onNewConversation);
    on<TrainerChatConversationSelected>(_onConversationSelected);
    on<TrainerChatModelSelected>(_onModelSelected);
    on<TrainerChatProgressReceived>(_onProgressReceived);
    on<TrainerChatTurnCancelRequested>(_onTurnCancelRequested);
    on<TrainerChatDraftChanged>(_onDraftChanged);
  }

  final TrainerRepository _repo;
  final String _templateId;

  /// Borradores del composer por conversationId (en memoria): sobreviven la
  /// destrucción del estado del composer al cerrar/reabrir la pantalla.
  final Map<String, String> _drafts = <String, String>{};

  /// true entre que el operador pide cancelar y que el POST abortado lanza:
  /// la guarda hace que el catch trague la excepción de cancelación en vez de
  /// pintarla como fallo real.
  bool _cancelRequested = false;

  /// Picker de archivos (nil ⇒ el composer oculta el clip — DX/tests).
  final MediaFilePicker? _picker;

  /// Realtime del turno (nil ⇒ sin indicador en vivo: el turno sigue funcionando
  /// con "Pensando…" estático). Best-effort, cosmético.
  final TrainerEvents? _events;

  /// Suscripción de progreso del turno en vuelo (per-turn): se abre al enviar y
  /// se cancela al volver el POST o al cerrarse el bloc.
  StreamSubscription<TrainerProgressEvent>? _progressSub;

  @override
  Future<void> close() {
    // Cancelar una suscripción SSE viva aguarda el desmonte del socket, que el
    // server mantiene abierto y puede no completar; el cierre del bloc no debe
    // colgarse en él.
    unawaited(_progressSub?.cancel());
    return super.close();
  }

  /// Allowlist de modelos, best-effort: el selector es accesorio — CUALQUIER
  /// fallo (backend sin la ruta, red, wire inesperado) lo oculta sin tocar
  /// la carga del hilo.
  Future<TrainerModels> _loadModels() async {
    try {
      return await _repo.listModels(templateId: _templateId);
    } on Object {
      return const TrainerModels(
        options: <TrainerModelOption>[],
        defaultId: '',
      );
    }
  }

  Future<List<TrainerMessage>> _loadMessages(String conversationId) async {
    final page = await _repo.listMessages(
      templateId: _templateId,
      conversationId: conversationId,
      limit: _pageLimit,
    );
    // El wire entrega DESC (recientes primero); el hilo renderiza ASC.
    return page.messages.reversed.toList(growable: false);
  }

  Future<void> _onStarted(
    TrainerChatStarted event,
    Emitter<TrainerChatState> emit,
  ) async {
    emit(const TrainerChatLoading());
    try {
      final convs = await _repo.listConversations(templateId: _templateId);
      final sorted = <TrainerConversation>[...convs]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final TrainerConversation conv;
      final List<TrainerConversation> list;
      if (sorted.isNotEmpty) {
        conv = sorted.first;
        list = sorted;
      } else {
        conv = await _repo.createConversation(
          templateId: _templateId,
          title: 'Entrenamiento',
        );
        list = <TrainerConversation>[conv];
      }
      final models = await _loadModels();
      emit(
        TrainerChatLoaded(
          conversation: conv,
          conversations: list,
          messages: await _loadMessages(conv.id),
          sending: false,
          models: models.options,
          defaultModelId: models.defaultId,
        ),
      );
    } on TrainerFailure catch (f) {
      emit(TrainerChatFailed(f));
    }
  }

  Future<void> _onMessageSent(
    TrainerChatMessageSent event,
    Emitter<TrainerChatState> emit,
  ) async {
    final current = state;
    if (current is! TrainerChatLoaded || current.sending) return;
    _cancelRequested = false;
    _drafts.remove(current.conversation.id);
    final optimistic = TrainerMessage(
      id: 'optimistic',
      conversationId: current.conversation.id,
      role: 'user',
      content: event.content,
      attachments: current.pendingAttachments,
      createdAt: DateTime.now().toUtc(),
    );
    emit(
      current.copyWith(
        messages: <TrainerMessage>[...current.messages, optimistic],
        sending: true,
        liveProgress: 'Pensando…',
        clearSendFailure: true,
        lastAttemptedContent: event.content,
        draft: '',
      ),
    );
    // Indicador en vivo: suscripción de progreso per-turn. Best-effort —
    // cosmético; si no hay puerto de eventos o el SSE no conecta, el indicador
    // se queda en "Pensando…". El cancel NO se espera: cancelar una suscripción
    // SSE viva aguarda el desmonte del socket (que el server mantiene abierto) y
    // puede no completar — esperarlo colgaría el cierre del turno en "Pensando…".
    unawaited(_progressSub?.cancel());
    _progressSub = _events
        ?.progress(_templateId, current.conversation.id)
        .listen(
          (e) {
            if (!isClosed) add(TrainerChatProgressReceived(e));
          },
          onError: (Object _) {},
        );
    try {
      await _repo.sendMessage(
        templateId: _templateId,
        conversationId: current.conversation.id,
        content: event.content,
        model: current.selectedModelId.isEmpty ? null : current.selectedModelId,
        attachments: current.pendingAttachments
            .map((a) => a.ref)
            .toList(growable: false),
      );
      unawaited(_progressSub?.cancel());
      _progressSub = null;
      emit(
        current.copyWith(
          messages: await _loadMessages(current.conversation.id),
          sending: false,
          liveProgress: '',
          clearSendFailure: true,
          pendingAttachments: const <TrainerAttachment>[],
          lastAttemptedContent: '',
        ),
      );
    } on TrainerFailure catch (f) {
      unawaited(_progressSub?.cancel());
      _progressSub = null;
      // El turno se canceló: el handler de cancelación ya dejó el estado limpio.
      // Tragamos la excepción del POST abortado en vez de pintarla como fallo.
      if (_cancelRequested) {
        _cancelRequested = false;
        return;
      }
      // Revertir el optimista: el server no persistió el turno (502 del motor
      // deja el user message fuera del hilo — reintentable). `current` conserva
      // los adjuntos pendientes y guardamos el texto para "Reintentar".
      emit(
        current.copyWith(
          sending: false,
          liveProgress: '',
          sendFailure: f,
          lastAttemptedContent: event.content,
        ),
      );
    }
  }

  Future<void> _onAttachRequested(
    TrainerChatAttachRequested event,
    Emitter<TrainerChatState> emit,
  ) async {
    final current = state;
    final picker = _picker;
    if (current is! TrainerChatLoaded || picker == null || current.attaching) {
      return;
    }
    final picked = await picker.pick();
    if (picked == null) return; // canceló: ni estado ni red.
    final afterPick = state;
    if (afterPick is! TrainerChatLoaded) return;
    emit(afterPick.copyWith(attaching: true));
    try {
      final att = await _repo.uploadAttachment(
        templateId: _templateId,
        bytes: picked.bytes,
        filename: picked.filename,
      );
      final cur = state;
      if (cur is! TrainerChatLoaded) return;
      emit(
        cur.copyWith(
          attaching: false,
          pendingAttachments: <TrainerAttachment>[
            ...cur.pendingAttachments,
            att,
          ],
        ),
      );
    } on TrainerFailure catch (f) {
      final cur = state;
      if (cur is! TrainerChatLoaded) return;
      emit(cur.copyWith(attaching: false, sendFailure: f));
    }
  }

  void _onAttachmentRemoved(
    TrainerChatAttachmentRemoved event,
    Emitter<TrainerChatState> emit,
  ) {
    final current = state;
    if (current is! TrainerChatLoaded) return;
    emit(
      current.copyWith(
        pendingAttachments: current.pendingAttachments
            .where((a) => a.ref != event.ref)
            .toList(growable: false),
      ),
    );
  }

  void _onModelSelected(
    TrainerChatModelSelected event,
    Emitter<TrainerChatState> emit,
  ) {
    final current = state;
    if (current is! TrainerChatLoaded) return;
    emit(current.copyWith(selectedModelId: event.modelId));
  }

  void _onTurnCancelRequested(
    TrainerChatTurnCancelRequested event,
    Emitter<TrainerChatState> emit,
  ) {
    final current = state;
    if (current is! TrainerChatLoaded || !current.sending) return;
    _cancelRequested = true;
    _repo.cancelSend();
    unawaited(_progressSub?.cancel());
    _progressSub = null;
    // Devolver el texto cancelado al borrador para que el operador lo reedite;
    // los adjuntos pendientes se conservan (current.copyWith no los toca).
    final cancelled = current.lastAttemptedContent;
    if (cancelled.isNotEmpty) {
      _drafts[current.conversation.id] = cancelled;
    }
    emit(
      current.copyWith(
        messages: current.messages
            .where((m) => m.id != 'optimistic')
            .toList(growable: false),
        sending: false,
        liveProgress: '',
        clearSendFailure: true,
        draft: cancelled,
      ),
    );
  }

  void _onDraftChanged(
    TrainerChatDraftChanged event,
    Emitter<TrainerChatState> emit,
  ) {
    final current = state;
    if (current is! TrainerChatLoaded) return;
    // Persistir sin re-emitir: el composer es la fuente de verdad mientras el
    // hilo está abierto; el borrador se siembra al cambiar de hilo o cancelar.
    _drafts[current.conversation.id] = event.text;
  }

  Future<void> _onConversationSelected(
    TrainerChatConversationSelected event,
    Emitter<TrainerChatState> emit,
  ) async {
    final current = state;
    if (current is! TrainerChatLoaded || current.sending) return;
    if (event.id == current.conversation.id) return; // ya activa
    TrainerConversation? target;
    for (final c in current.conversations) {
      if (c.id == event.id) {
        target = c;
        break;
      }
    }
    if (target == null) return;
    try {
      emit(
        current.copyWith(
          conversation: target,
          messages: await _loadMessages(target.id),
          clearSendFailure: true,
          draft: _drafts[target.id] ?? '',
        ),
      );
    } on TrainerFailure catch (f) {
      emit(current.copyWith(sendFailure: f));
    }
  }

  void _onProgressReceived(
    TrainerChatProgressReceived event,
    Emitter<TrainerChatState> emit,
  ) {
    final current = state;
    if (current is! TrainerChatLoaded || !current.sending) return;
    if (event.event.conversationId != current.conversation.id) return;
    final label = _progressLabel(event.event);
    if (label.isEmpty || label == current.liveProgress) return;
    emit(current.copyWith(liveProgress: label));
  }

  String _progressLabel(TrainerProgressEvent e) {
    if (e.isTool) {
      return e.toolName.isNotEmpty ? 'Usando ${e.toolName}…' : 'Trabajando…';
    }
    if (e.isThinking) return 'Pensando…';
    return ''; // terminal: el cierre del POST limpia el indicador.
  }

  Future<void> _onNewConversation(
    TrainerChatNewConversationRequested event,
    Emitter<TrainerChatState> emit,
  ) async {
    // La allowlist de modelos y la elección del operador son de la pantalla
    // (template/servidor), no de la conversación: deben sobrevivir al iniciar
    // un hilo nuevo, o el selector de modelo desaparecería. Se heredan del
    // estado cargado vivo; si no lo había (nueva conversación lanzada desde
    // Loading/Failed), se recargan best-effort.
    final preserved = state is TrainerChatLoaded
        ? state as TrainerChatLoaded
        : null;
    emit(const TrainerChatLoading());
    try {
      final conv = await _repo.createConversation(
        templateId: _templateId,
        title: 'Entrenamiento',
      );
      final models = preserved != null
          ? TrainerModels(
              options: preserved.models,
              defaultId: preserved.defaultModelId,
            )
          : await _loadModels();
      emit(
        TrainerChatLoaded(
          conversation: conv,
          conversations: <TrainerConversation>[
            conv,
            ...?preserved?.conversations,
          ],
          messages: const <TrainerMessage>[],
          sending: false,
          models: models.options,
          defaultModelId: models.defaultId,
          selectedModelId: preserved?.selectedModelId ?? '',
        ),
      );
    } on TrainerFailure catch (f) {
      emit(TrainerChatFailed(f));
    }
  }
}
