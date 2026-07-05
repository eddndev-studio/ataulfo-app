import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/session_status.dart';
import '../../domain/failures/bots_failure.dart';
import '../../domain/repositories/bot_session_repository.dart';

/// Estado de sesión de canal por bot para el listado (S04). El dato no viene en
/// `GET /bots`; se abanica `GET /bots/:id/session` tras cargar la lista y se
/// puebla por bot conforme llega. Un bot sin dato (fetch fallido o aún en
/// vuelo) simplemente no aparece en el mapa: la UI no pinta su indicador.
class BotSessionsState {
  const BotSessionsState(this.byBot);
  const BotSessionsState.empty() : byBot = const <String, SessionState>{};

  final Map<String, SessionState> byBot;

  /// Estado de sesión conocido de un bot, o null si no hay dato honesto.
  SessionState? stateFor(String botId) => byBot[botId];

  @override
  bool operator ==(Object other) {
    if (other is! BotSessionsState) return false;
    if (other.byBot.length != byBot.length) return false;
    for (final entry in byBot.entries) {
      if (other.byBot[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    byBot.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

/// Compañero page-scoped del listado de bots: mantiene el estado de sesión de
/// WhatsApp por bot. Separado del `BotsBloc` (que sólo lista) para no mezclar
/// responsabilidades — aquí vive el abanico de consultas con cota de
/// concurrencia y la política fail-soft por bot.
class BotSessionsCubit extends Cubit<BotSessionsState> {
  BotSessionsCubit(this._repo) : super(const BotSessionsState.empty());

  final BotSessionRepository _repo;

  /// Tope de consultas simultáneas del abanico: sondear todas las sesiones a la
  /// vez castigaría al backend en orgs con muchos bots.
  static const int _maxConcurrent = 4;

  /// Invalida abanicos anteriores: un refresh incrementa la generación y los
  /// resultados en vuelo del abanico viejo se descartan al emitir.
  int _generation = 0;

  /// Consulta la sesión de cada bot y va poblando el estado conforme llega.
  /// Reusa lo ya conocido como base (sin parpadeo en refresh) y poda los bots
  /// que ya no están en la lista.
  Future<void> load(List<String> botIds) async {
    final generation = ++_generation;
    final present = botIds.toSet();
    final byBot = Map<String, SessionState>.of(state.byBot)
      ..removeWhere((id, _) => !present.contains(id));
    _emit(generation, byBot);

    final queue = List<String>.of(botIds);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final id = queue.removeLast();
        try {
          final status = await _repo.getSessionState(id);
          if (generation != _generation || isClosed) return;
          byBot[id] = status.state;
          _emit(generation, byBot);
        } on BotsFailure {
          // Fail-soft: un fetch fallido no inventa estado. El bot queda sin
          // indicador, o conserva el último bueno si ya lo tenía.
        }
      }
    }

    final workerCount = math.min(_maxConcurrent, botIds.length);
    await Future.wait(<Future<void>>[
      for (var i = 0; i < workerCount; i++) worker(),
    ]);
  }

  void _emit(int generation, Map<String, SessionState> byBot) {
    if (generation != _generation || isClosed) return;
    emit(BotSessionsState(Map<String, SessionState>.of(byBot)));
  }
}
