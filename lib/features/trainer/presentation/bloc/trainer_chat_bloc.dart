import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/trainer_conversation.dart';
import '../../domain/entities/trainer_message.dart';
import '../../domain/failures/trainer_failure.dart';
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
  });

  final TrainerConversation conversation;

  /// Hilo en orden cronológico ASC (listo para render).
  final List<TrainerMessage> messages;

  /// true mientras el turno viaja (composer bloqueado + typing indicator).
  final bool sending;

  /// Fallo del ÚLTIMO turno (el hilo sigue usable); null si no hubo.
  final TrainerFailure? sendFailure;

  TrainerChatLoaded copyWith({
    List<TrainerMessage>? messages,
    bool? sending,
    TrainerFailure? sendFailure,
    bool clearSendFailure = false,
  }) => TrainerChatLoaded(
    conversation: conversation,
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    sendFailure: clearSendFailure ? null : (sendFailure ?? this.sendFailure),
  );

  @override
  bool operator ==(Object other) =>
      other is TrainerChatLoaded &&
      other.conversation == conversation &&
      listEquals(other.messages, messages) &&
      other.sending == sending &&
      other.sendFailure == sendFailure;

  @override
  int get hashCode =>
      Object.hash(conversation, Object.hashAll(messages), sending, sendFailure);
}

class TrainerChatBloc extends Bloc<TrainerChatEvent, TrainerChatState> {
  TrainerChatBloc({required TrainerRepository repo, required String templateId})
    : _repo = repo,
      _templateId = templateId,
      super(const TrainerChatLoading()) {
    on<TrainerChatStarted>(_onStarted);
    on<TrainerChatMessageSent>(_onMessageSent);
    on<TrainerChatNewConversationRequested>(_onNewConversation);
  }

  final TrainerRepository _repo;
  final String _templateId;

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
      emit(
        TrainerChatLoaded(
          conversation: conv,
          messages: await _loadMessages(conv.id),
          sending: false,
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
      );
      emit(
        current.copyWith(
          messages: await _loadMessages(current.conversation.id),
          sending: false,
          clearSendFailure: true,
        ),
      );
    } on TrainerFailure catch (f) {
      // Revertir el optimista: el server no persistió el turno (502 del
      // motor deja el user message fuera del hilo — reintentable).
      emit(current.copyWith(sending: false, sendFailure: f));
    }
  }

  Future<void> _onNewConversation(
    TrainerChatNewConversationRequested event,
    Emitter<TrainerChatState> emit,
  ) async {
    emit(const TrainerChatLoading());
    try {
      final conv = await _repo.createConversation(
        templateId: _templateId,
        title: 'Entrenamiento',
      );
      emit(
        TrainerChatLoaded(
          conversation: conv,
          messages: const <TrainerMessage>[],
          sending: false,
        ),
      );
    } on TrainerFailure catch (f) {
      emit(TrainerChatFailed(f));
    }
  }
}
