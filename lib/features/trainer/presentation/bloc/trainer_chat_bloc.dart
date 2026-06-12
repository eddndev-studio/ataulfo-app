import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/trainer_attachment.dart';
import '../../domain/entities/trainer_conversation.dart';
import '../../domain/entities/trainer_message.dart';
import '../../domain/entities/trainer_models.dart';
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
    this.sendFailure,
    this.models = const <TrainerModelOption>[],
    this.defaultModelId = '',
    this.selectedModelId = '',
    this.pendingAttachments = const <TrainerAttachment>[],
    this.attaching = false,
  });

  final TrainerConversation conversation;

  /// Hilo en orden cronológico ASC (listo para render).
  final List<TrainerMessage> messages;

  /// true mientras el turno viaja (composer bloqueado + typing indicator).
  final bool sending;

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

  TrainerChatLoaded copyWith({
    List<TrainerMessage>? messages,
    bool? sending,
    TrainerFailure? sendFailure,
    bool clearSendFailure = false,
    String? selectedModelId,
    List<TrainerAttachment>? pendingAttachments,
    bool? attaching,
  }) => TrainerChatLoaded(
    conversation: conversation,
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    sendFailure: clearSendFailure ? null : (sendFailure ?? this.sendFailure),
    models: models,
    defaultModelId: defaultModelId,
    selectedModelId: selectedModelId ?? this.selectedModelId,
    pendingAttachments: pendingAttachments ?? this.pendingAttachments,
    attaching: attaching ?? this.attaching,
  );

  @override
  bool operator ==(Object other) =>
      other is TrainerChatLoaded &&
      other.conversation == conversation &&
      listEquals(other.messages, messages) &&
      other.sending == sending &&
      other.sendFailure == sendFailure &&
      listEquals(other.models, models) &&
      other.defaultModelId == defaultModelId &&
      other.selectedModelId == selectedModelId &&
      listEquals(other.pendingAttachments, pendingAttachments) &&
      other.attaching == attaching;

  @override
  int get hashCode => Object.hash(
    conversation,
    Object.hashAll(messages),
    sending,
    sendFailure,
    Object.hashAll(models),
    defaultModelId,
    selectedModelId,
    Object.hashAll(pendingAttachments),
    attaching,
  );
}

class TrainerChatBloc extends Bloc<TrainerChatEvent, TrainerChatState> {
  TrainerChatBloc({
    required TrainerRepository repo,
    required String templateId,
    MediaFilePicker? picker,
  }) : _repo = repo,
       _templateId = templateId,
       _picker = picker,
       super(const TrainerChatLoading()) {
    on<TrainerChatStarted>(_onStarted);
    on<TrainerChatMessageSent>(_onMessageSent);
    on<TrainerChatAttachRequested>(_onAttachRequested);
    on<TrainerChatAttachmentRemoved>(_onAttachmentRemoved);
    on<TrainerChatNewConversationRequested>(_onNewConversation);
    on<TrainerChatModelSelected>(_onModelSelected);
  }

  final TrainerRepository _repo;
  final String _templateId;

  /// Picker de archivos (nil ⇒ el composer oculta el clip — DX/tests).
  final MediaFilePicker? _picker;

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
      final conv = convs.isNotEmpty
          ? convs.first
          : await _repo.createConversation(
              templateId: _templateId,
              title: 'Entrenamiento',
            );
      final models = await _loadModels();
      emit(
        TrainerChatLoaded(
          conversation: conv,
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
        clearSendFailure: true,
      ),
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
      emit(
        current.copyWith(
          messages: await _loadMessages(current.conversation.id),
          sending: false,
          clearSendFailure: true,
          pendingAttachments: const <TrainerAttachment>[],
        ),
      );
    } on TrainerFailure catch (f) {
      // Revertir el optimista: el server no persistió el turno (502 del
      // motor deja el user message fuera del hilo — reintentable).
      emit(current.copyWith(sending: false, sendFailure: f));
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
