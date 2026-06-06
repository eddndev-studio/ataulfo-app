import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/quick_reply.dart';
import '../../domain/failures/quick_replies_failure.dart';
import '../../domain/repositories/quick_replies_repository.dart';

/// Bloc del catálogo de respuestas rápidas WhatsApp de un bot (S23). Se construye
/// con el `botId` (la ruta del hilo lo aporta) y carga el catálogo al montarse:
/// el composer lee el último estado para ofrecer las respuestas en el selector ⚡.
///
/// **Caché de sesión + stale-while-revalidate.** El repo cachea el catálogo por
/// bot durante la sesión. Si ya hay catálogo cacheado, el bloc SIEMBRA su estado
/// inicial en `Loaded` (sin el "cargando" de varios segundos al reabrir el hilo)
/// y la carga revalida en silencio: no re-emite `Loading` ni borra el catálogo
/// si la revalidación falla. La primera apertura (sin caché) sí muestra el
/// spinner. Reabrir el hilo deja de mostrar la pantalla de carga.
///
/// SOLO LECTURA y SIN realtime: a diferencia del catálogo de etiquetas (S21), no
/// se abre un segundo stream SSE por hilo. Las respuestas rápidas casi nunca
/// cambian mientras se atiende una conversación, y abrir otra conexión a
/// `/events/stream` (que el backend ya expone para `quick_reply.*`) duplicaría el
/// fan-out por hilo sin beneficio real. La actualización en vivo queda diferida.
///
/// El estado conserva el espejo COMPLETO (incluidos tombstones `deleted:true`);
/// el selector filtra los activos.
class QuickRepliesBloc extends Bloc<QuickRepliesEvent, QuickRepliesState> {
  QuickRepliesBloc({
    required QuickRepliesRepository repo,
    required String botId,
  }) : _repo = repo,
       _botId = botId,
       super(_seed(repo, botId)) {
    on<QuickRepliesLoadRequested>(_onLoad);
  }

  /// Estado inicial: `Loaded` si el repo ya tiene el catálogo cacheado de este
  /// bot (reapertura ⇒ sin flash de carga), o `Loading` en frío. `[]` cacheada
  /// siembra `Loaded([])` (bot sin respuestas), distinto de `null` (sin caché).
  static QuickRepliesState _seed(QuickRepliesRepository repo, String botId) {
    final cached = repo.cachedCatalog(botId);
    return cached == null
        ? const QuickRepliesLoading()
        : QuickRepliesLoaded(cached);
  }

  final QuickRepliesRepository _repo;
  final String _botId;

  /// El bot dueño de este catálogo (la página lo usa al construir el bloc).
  String get botId => _botId;

  Future<void> _onLoad(
    QuickRepliesLoadRequested event,
    Emitter<QuickRepliesState> emit,
  ) async {
    final hadData = state is QuickRepliesLoaded;
    // Solo re-mostramos el spinner al reintentar desde un fallo. En frío el seed
    // ya es `Loading`; con datos (caché) revalidamos en silencio, sin flash.
    if (state is QuickRepliesFailed) {
      emit(const QuickRepliesLoading());
    }
    try {
      final next = QuickRepliesLoaded(await _repo.listCatalog(_botId));
      // Revalidación idéntica al estado actual (caché ya fresca) ⇒ no re-emitir:
      // la primera emisión del bloc no se deduplica por valor, así que el guard
      // evita un evento redundante al reabrir un hilo sin cambios.
      if (state != next) {
        emit(next);
      }
    } on QuickRepliesFailure catch (f) {
      // Una revalidación fallida NO borra un catálogo ya cargado: el selector
      // sigue ofreciendo la última copia buena. El error solo aflora en frío.
      if (!hadData) {
        emit(QuickRepliesFailed(f));
      }
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
