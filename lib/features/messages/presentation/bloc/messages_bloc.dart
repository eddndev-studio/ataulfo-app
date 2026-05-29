import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/message.dart';
import '../../domain/failures/messages_failure.dart';
import '../../domain/repositories/messages_repository.dart';

/// Bloc del hilo de mensajes (S09 RF#5). Se construye con `botId` + `chatLid`
/// (los aporta la ruta `/bots/:id/sessions/:chatLid`). Abre en la cola
/// (mensajes recientes) y carga tramos más viejos al pedir `Older`,
/// prependiéndolos — el modelo de scroll de un chat.
///
/// `prevCursor` dentro de `MessagesLoaded` es el cursor hacia atrás: `null` ⇒
/// inicio del hilo (no hay más viejos). `isLoadingOlder` deja que la UI muestre
/// el spinner de "cargando más" sin ocultar el hilo ya pintado.
class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  MessagesBloc({
    required MessagesRepository repo,
    required String botId,
    required String chatLid,
  }) : _repo = repo,
       _botId = botId,
       _chatLid = chatLid,
       super(const MessagesInitial()) {
    on<MessagesLoadRequested>(_onLoad);
    on<MessagesOlderRequested>(_onOlder);
  }

  final MessagesRepository _repo;
  final String _botId;
  final String _chatLid;

  Future<void> _onLoad(
    MessagesLoadRequested event,
    Emitter<MessagesState> emit,
  ) async {
    emit(const MessagesLoading());
    try {
      final page = await _repo.thread(_botId, _chatLid);
      emit(
        MessagesLoaded(
          items: page.messages,
          prevCursor: page.prevCursor,
          isLoadingOlder: false,
        ),
      );
    } on MessagesFailure catch (f) {
      emit(MessagesFailed(f));
    }
  }

  Future<void> _onOlder(
    MessagesOlderRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final current = state;
    // Sólo paginamos hacia arriba desde un hilo ya cargado, con más tramo
    // disponible (prevCursor != null) y sin otra carga en vuelo.
    if (current is! MessagesLoaded ||
        current.prevCursor == null ||
        current.isLoadingOlder) {
      return;
    }
    emit(
      MessagesLoaded(
        items: current.items,
        prevCursor: current.prevCursor,
        isLoadingOlder: true,
      ),
    );
    try {
      final older = await _repo.thread(
        _botId,
        _chatLid,
        cursor: current.prevCursor,
      );
      // El tramo viejo es estrictamente anterior (keyset `<`): se prepende sin
      // solape ni dedup. Ambas listas vienen en ASC.
      emit(
        MessagesLoaded(
          items: <Message>[...older.messages, ...current.items],
          prevCursor: older.prevCursor,
          isLoadingOlder: false,
        ),
      );
    } on MessagesFailure {
      // Fallar al cargar más viejos NO derriba el hilo ya pintado: se apaga el
      // spinner y se conserva el estado (el usuario puede reintentar el scroll).
      emit(
        MessagesLoaded(
          items: current.items,
          prevCursor: current.prevCursor,
          isLoadingOlder: false,
        ),
      );
    }
  }
}

// Events --------------------------------------------------------------------

sealed class MessagesEvent {
  const MessagesEvent();
}

/// Carga inicial: la cola (mensajes más recientes) del hilo.
class MessagesLoadRequested extends MessagesEvent {
  const MessagesLoadRequested();
  @override
  bool operator ==(Object other) => other is MessagesLoadRequested;
  @override
  int get hashCode => (MessagesLoadRequested).hashCode;
}

/// Cargar el tramo inmediatamente más viejo (scroll hacia arriba).
class MessagesOlderRequested extends MessagesEvent {
  const MessagesOlderRequested();
  @override
  bool operator ==(Object other) => other is MessagesOlderRequested;
  @override
  int get hashCode => (MessagesOlderRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class MessagesState {
  const MessagesState();
}

class MessagesInitial extends MessagesState {
  const MessagesInitial();
  @override
  bool operator ==(Object other) => other is MessagesInitial;
  @override
  int get hashCode => (MessagesInitial).hashCode;
}

class MessagesLoading extends MessagesState {
  const MessagesLoading();
  @override
  bool operator ==(Object other) => other is MessagesLoading;
  @override
  int get hashCode => (MessagesLoading).hashCode;
}

class MessagesLoaded extends MessagesState {
  const MessagesLoaded({
    required this.items,
    required this.prevCursor,
    required this.isLoadingOlder,
  });

  /// Mensajes acumulados en orden ascendente (más viejo→más nuevo).
  final List<Message> items;

  /// Cursor hacia atrás; `null` ⇒ inicio del hilo (no hay más viejos).
  final String? prevCursor;

  /// Hay un tramo más viejo cargándose (spinner arriba, hilo visible).
  final bool isLoadingOlder;

  bool get hasMore => prevCursor != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MessagesLoaded) return false;
    if (other.prevCursor != prevCursor) return false;
    if (other.isLoadingOlder != isLoadingOlder) return false;
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(items), prevCursor, isLoadingOlder);
}

class MessagesFailed extends MessagesState {
  const MessagesFailed(this.failure);

  final MessagesFailure failure;

  @override
  bool operator ==(Object other) =>
      other is MessagesFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
