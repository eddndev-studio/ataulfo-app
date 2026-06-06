import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/quick_reply.dart';
import '../../domain/failures/quick_replies_failure.dart';
import '../../domain/repositories/quick_replies_repository.dart';

/// Bloc del catálogo de respuestas rápidas WhatsApp de un bot (S23). Se construye
/// con el `botId` (la ruta del hilo lo aporta) y carga el catálogo una vez al
/// montarse: el composer lee el último estado para ofrecer las respuestas en el
/// selector ⚡.
///
/// SOLO LECTURA y SIN realtime: a diferencia del catálogo de etiquetas (S21), no
/// se abre un segundo stream SSE por hilo. Las respuestas rápidas casi nunca
/// cambian mientras se atiende una conversación, y abrir otra conexión a
/// `/events/stream` (que el backend ya expone para `quick_reply.*`) duplicaría el
/// fan-out por hilo sin beneficio real. La actualización en vivo queda diferida;
/// reabrir el hilo recarga el catálogo.
///
/// El estado conserva el espejo COMPLETO (incluidos tombstones `deleted:true`);
/// el selector filtra los activos.
class QuickRepliesBloc extends Bloc<QuickRepliesEvent, QuickRepliesState> {
  QuickRepliesBloc({
    required QuickRepliesRepository repo,
    required String botId,
  }) : _repo = repo,
       _botId = botId,
       super(const QuickRepliesLoading()) {
    on<QuickRepliesLoadRequested>(_onLoad);
  }

  final QuickRepliesRepository _repo;
  final String _botId;

  /// El bot dueño de este catálogo (la página lo usa al construir el bloc).
  String get botId => _botId;

  Future<void> _onLoad(
    QuickRepliesLoadRequested event,
    Emitter<QuickRepliesState> emit,
  ) async {
    if (state is! QuickRepliesLoading) {
      emit(const QuickRepliesLoading());
    }
    try {
      final items = await _repo.listCatalog(_botId);
      emit(QuickRepliesLoaded(items));
    } on QuickRepliesFailure catch (f) {
      emit(QuickRepliesFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class QuickRepliesEvent {
  const QuickRepliesEvent();
}

/// Pide (o recarga) el catálogo de respuestas rápidas del bot.
class QuickRepliesLoadRequested extends QuickRepliesEvent {
  const QuickRepliesLoadRequested();
  @override
  bool operator ==(Object other) => other is QuickRepliesLoadRequested;
  @override
  int get hashCode => (QuickRepliesLoadRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class QuickRepliesState {
  const QuickRepliesState();
}

class QuickRepliesLoading extends QuickRepliesState {
  const QuickRepliesLoading();
  @override
  bool operator ==(Object other) => other is QuickRepliesLoading;
  @override
  int get hashCode => (QuickRepliesLoading).hashCode;
}

class QuickRepliesLoaded extends QuickRepliesState {
  const QuickRepliesLoaded(this.items);

  /// Espejo completo del catálogo (incluye tombstones `deleted:true`); el
  /// selector filtra los activos.
  final List<QuickReply> items;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QuickRepliesLoaded) return false;
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items);
}

class QuickRepliesFailed extends QuickRepliesState {
  const QuickRepliesFailed(this.failure);

  final QuickRepliesFailure failure;

  @override
  bool operator ==(Object other) =>
      other is QuickRepliesFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}
