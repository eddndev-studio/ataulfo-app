import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/pa_conversation.dart';
import '../../domain/entities/pa_message.dart';
import '../../domain/entities/pa_models.dart';
import '../../domain/entities/pa_progress.dart';
import '../../domain/failures/pa_failure.dart';
import '../../domain/repositories/platform_agent_repository.dart';

/// Página de historial que el chat carga por turno. El POST síncrono ya
/// devuelve el assistant final, pero el hilo completo (tool results) vive en
/// el server: tras cada turno se RECARGA.
const int _pageLimit = 50;
const String _newTitle = 'Asistente';

sealed class PaChatEvent {
  const PaChatEvent();
}

final class PaChatStarted extends PaChatEvent {
  const PaChatStarted();
}

final class PaChatMessageSent extends PaChatEvent {
  const PaChatMessageSent(this.content);

  final String content;

  @override
  bool operator ==(Object other) =>
      other is PaChatMessageSent && other.content == content;

  @override
  int get hashCode => content.hashCode;
}

final class PaChatNewConversationRequested extends PaChatEvent {
  const PaChatNewConversationRequested();
}

final class PaChatConversationSelected extends PaChatEvent {
  const PaChatConversationSelected(this.id);

  final String id;

  @override
  bool operator ==(Object other) =>
      other is PaChatConversationSelected && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// El operador elige el modelo para los próximos turnos. id vacío ⇒ vuelve al
/// default de la plataforma (el turno viaja sin model).
final class PaChatModelSelected extends PaChatEvent {
  const PaChatModelSelected(this.modelId);

  final String modelId;

  @override
  bool operator ==(Object other) =>
      other is PaChatModelSelected && other.modelId == modelId;

  @override
  int get hashCode => modelId.hashCode;
}

/// Interno: un frame de progreso del SSE del turno en vuelo. Alimenta el
/// indicador en vivo; no toca el hilo de mensajes.
final class PaChatProgressReceived extends PaChatEvent {
  const PaChatProgressReceived(this.event);

  final PaProgressEvent event;
}

sealed class PaChatState {
  const PaChatState();
}

final class PaChatLoading extends PaChatState {
  const PaChatLoading();

  @override
  bool operator ==(Object other) => other is PaChatLoading;

  @override
  int get hashCode => (PaChatLoading).hashCode;
}

final class PaChatFailed extends PaChatState {
  const PaChatFailed(this.failure);

  final PaFailure failure;

  @override
  bool operator ==(Object other) =>
      other is PaChatFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

final class PaChatLoaded extends PaChatState {
  const PaChatLoaded({
    required this.conversations,
    required this.activeConversation,
    required this.messages,
    required this.sending,
    this.sendFailure,
    this.liveProgress = '',
    this.models = const <PaModelOption>[],
    this.defaultModelId = '',
    this.selectedModelId = '',
  });

  /// Hilos del operador, DESC por updatedAt (para el selector de historial).
  final List<PaConversation> conversations;

  /// Hilo abierto.
  final PaConversation activeConversation;

  /// Mensajes del hilo activo en orden cronológico ASC (listo para render).
  final List<PaMessage> messages;

  /// true mientras el turno viaja (composer bloqueado + indicador en vivo).
  final bool sending;

  /// Fallo del ÚLTIMO turno (el hilo sigue usable); null si no hubo.
  final PaFailure? sendFailure;

  /// Etiqueta del indicador en vivo durante el turno ("Pensando…", "Usando
  /// {tool}…"); vacía cuando no hay turno en vuelo.
  final String liveProgress;

  /// Allowlist de modelos (best-effort: vacía oculta el selector — backend sin
  /// la ruta o fallo de carga).
  final List<PaModelOption> models;

  /// Modelo default de la plataforma (informativo, para marcarlo en el menú).
  final String defaultModelId;

  /// Elección vigente del operador; '' = default (el turno viaja sin model).
  final String selectedModelId;

  PaChatLoaded copyWith({
    List<PaConversation>? conversations,
    PaConversation? activeConversation,
    List<PaMessage>? messages,
    bool? sending,
    PaFailure? sendFailure,
    bool clearSendFailure = false,
    String? liveProgress,
    String? selectedModelId,
  }) => PaChatLoaded(
    conversations: conversations ?? this.conversations,
    activeConversation: activeConversation ?? this.activeConversation,
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    sendFailure: clearSendFailure ? null : (sendFailure ?? this.sendFailure),
    liveProgress: liveProgress ?? this.liveProgress,
    models: models,
    defaultModelId: defaultModelId,
    selectedModelId: selectedModelId ?? this.selectedModelId,
  );

  @override
  bool operator ==(Object other) =>
      other is PaChatLoaded &&
      listEquals(other.conversations, conversations) &&
      other.activeConversation == activeConversation &&
      listEquals(other.messages, messages) &&
      other.sending == sending &&
      other.sendFailure == sendFailure &&
      other.liveProgress == liveProgress &&
      listEquals(other.models, models) &&
      other.defaultModelId == defaultModelId &&
      other.selectedModelId == selectedModelId;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(conversations),
    activeConversation,
    Object.hashAll(messages),
    sending,
    sendFailure,
    liveProgress,
    Object.hashAll(models),
    defaultModelId,
    selectedModelId,
  );
}

class PlatformAgentChatBloc extends Bloc<PaChatEvent, PaChatState> {
  PlatformAgentChatBloc({
    required PlatformAgentRepository repo,
    required PlatformAgentEvents events,
  }) : _repo = repo,
       _events = events,
       super(const PaChatLoading()) {
    on<PaChatStarted>(_onStarted);
    on<PaChatMessageSent>(_onMessageSent);
    on<PaChatNewConversationRequested>(_onNewConversation);
    on<PaChatConversationSelected>(_onConversationSelected);
    on<PaChatProgressReceived>(_onProgressReceived);
    on<PaChatModelSelected>(_onModelSelected);
  }

  final PlatformAgentRepository _repo;
  final PlatformAgentEvents _events;

  /// Suscripción de progreso del turno en vuelo (per-turn): se abre al enviar
  /// y se cancela al volver el POST o al cerrarse el bloc.
  StreamSubscription<PaProgressEvent>? _progressSub;

  @override
  Future<void> close() async {
    await _progressSub?.cancel();
    return super.close();
  }

  Future<List<PaMessage>> _loadMessages(String conversationId) async {
    final page = await _repo.listMessages(
      conversationId: conversationId,
      limit: _pageLimit,
    );
    // El wire entrega DESC (recientes primero); el hilo renderiza ASC.
    return page.messages.reversed.toList(growable: false);
  }

  /// Allowlist de modelos, best-effort: el selector es accesorio — CUALQUIER
  /// fallo (backend sin la ruta, red, wire inesperado) lo oculta sin tocar la
  /// carga del hilo.
  Future<PaModels> _loadModels() async {
    try {
      return await _repo.listModels();
    } on Object {
      return const PaModels(options: <PaModelOption>[], defaultId: '');
    }
  }

  Future<void> _onStarted(
    PaChatStarted event,
    Emitter<PaChatState> emit,
  ) async {
    emit(const PaChatLoading());
    try {
      final convs = await _repo.listConversations();
      final active = convs.isNotEmpty
          ? convs.first
          : await _repo.createConversation(title: _newTitle);
      final list = convs.isNotEmpty ? convs : <PaConversation>[active];
      final models = await _loadModels();
      emit(
        PaChatLoaded(
          conversations: list,
          activeConversation: active,
          messages: await _loadMessages(active.id),
          sending: false,
          models: models.options,
          defaultModelId: models.defaultId,
        ),
      );
    } on PaFailure catch (f) {
      emit(PaChatFailed(f));
    }
  }

  Future<void> _onMessageSent(
    PaChatMessageSent event,
    Emitter<PaChatState> emit,
  ) async {
    final current = state;
    if (current is! PaChatLoaded || current.sending) return;
    final convId = current.activeConversation.id;
    final optimistic = PaMessage(
      id: 'optimistic',
      conversationId: convId,
      role: 'user',
      content: event.content,
      createdAt: DateTime.now().toUtc(),
    );
    emit(
      current.copyWith(
        messages: <PaMessage>[...current.messages, optimistic],
        sending: true,
        liveProgress: 'Pensando…',
        clearSendFailure: true,
      ),
    );
    // Indicador en vivo: suscripción de progreso per-turn. Best-effort —
    // cosmético; si el SSE no conecta, el indicador se queda en "Pensando…".
    await _progressSub?.cancel();
    _progressSub = _events.progress(convId).listen((e) {
      if (!isClosed) add(PaChatProgressReceived(e));
    }, onError: (Object _) {});
    try {
      await _repo.sendMessage(
        conversationId: convId,
        content: event.content,
        model: current.selectedModelId.isEmpty ? null : current.selectedModelId,
      );
      await _progressSub?.cancel();
      _progressSub = null;
      emit(
        current.copyWith(
          messages: await _loadMessages(convId),
          sending: false,
          liveProgress: '',
          clearSendFailure: true,
        ),
      );
    } on PaFailure catch (f) {
      // Revertir el optimista: el 502 deja el user message fuera del hilo
      // (reintentable). `current` es el estado pre-optimista.
      await _progressSub?.cancel();
      _progressSub = null;
      emit(current.copyWith(sending: false, liveProgress: '', sendFailure: f));
    }
  }

  void _onProgressReceived(
    PaChatProgressReceived event,
    Emitter<PaChatState> emit,
  ) {
    final current = state;
    if (current is! PaChatLoaded || !current.sending) return;
    if (event.event.conversationId != current.activeConversation.id) return;
    final label = _progressLabel(event.event);
    if (label.isEmpty || label == current.liveProgress) return;
    emit(current.copyWith(liveProgress: label));
  }

  String _progressLabel(PaProgressEvent e) {
    if (e.isTool) {
      return e.toolName.isNotEmpty ? 'Usando ${e.toolName}…' : 'Trabajando…';
    }
    if (e.isThinking) return 'Pensando…';
    return ''; // terminal: el cierre del POST limpia el indicador.
  }

  Future<void> _onNewConversation(
    PaChatNewConversationRequested event,
    Emitter<PaChatState> emit,
  ) async {
    final preserved = state is PaChatLoaded ? state as PaChatLoaded : null;
    try {
      final conv = await _repo.createConversation(title: _newTitle);
      final convs = preserved != null
          ? <PaConversation>[conv, ...preserved.conversations]
          : <PaConversation>[conv];
      // El selector de modelo es de la pantalla, no del hilo: debe sobrevivir
      // al iniciar una conversación nueva (heredado del estado vivo; si no lo
      // había, se recarga best-effort).
      final models = preserved != null
          ? PaModels(
              options: preserved.models,
              defaultId: preserved.defaultModelId,
            )
          : await _loadModels();
      emit(
        PaChatLoaded(
          conversations: convs,
          activeConversation: conv,
          messages: const <PaMessage>[],
          sending: false,
          models: models.options,
          defaultModelId: models.defaultId,
          selectedModelId: preserved?.selectedModelId ?? '',
        ),
      );
    } on PaFailure catch (f) {
      emit(PaChatFailed(f));
    }
  }

  Future<void> _onConversationSelected(
    PaChatConversationSelected event,
    Emitter<PaChatState> emit,
  ) async {
    final current = state;
    if (current is! PaChatLoaded || current.sending) return;
    if (event.id == current.activeConversation.id) return;
    PaConversation? target;
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
          activeConversation: target,
          messages: await _loadMessages(target.id),
          liveProgress: '',
          clearSendFailure: true,
        ),
      );
    } on PaFailure catch (f) {
      emit(current.copyWith(sendFailure: f));
    }
  }

  void _onModelSelected(PaChatModelSelected event, Emitter<PaChatState> emit) {
    final current = state;
    if (current is! PaChatLoaded) return;
    emit(current.copyWith(selectedModelId: event.modelId));
  }
}
