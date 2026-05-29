import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/connect_link.dart';
import '../../domain/failures/bots_failure.dart';
import '../../domain/repositories/bot_session_repository.dart';

/// Bloc del flujo "compartir enlace de conexión" (S04). Vida atada a la ruta
/// `/bots/:id/connect`: arranca en Loading y, al recibir [BotConnectStarted],
/// arranca la sesión del bot y emite un enlace público listo para compartir.
///
/// Orden deliberado start → emitir token: arrancar la sesión primero hace que
/// el QR ya exista cuando el tercero abra el enlace (sin pasar por "esperando
/// al operador"); emitir el token al final corre su TTL lo más tarde posible,
/// maximizando la ventana para escanear. El backend tolera ambos órdenes; la
/// elección es de UX, no de contrato.
class BotConnectBloc extends Bloc<BotConnectEvent, BotConnectState> {
  BotConnectBloc({required BotSessionRepository repo, required String botId})
    : _repo = repo,
      _botId = botId,
      super(const BotConnectLoading()) {
    on<BotConnectStarted>(_onStarted);
  }

  final BotSessionRepository _repo;
  final String _botId;

  Future<void> _onStarted(
    BotConnectStarted event,
    Emitter<BotConnectState> emit,
  ) async {
    // Sólo re-emitimos Loading en un retry (desde Failed); el primer load
    // post-construcción ya está en Loading y evitar el duplicado mantiene
    // el stream limpio. Mismo patrón que BotDetailBloc.
    if (state is! BotConnectLoading) {
      emit(const BotConnectLoading());
    }
    try {
      await _repo.startSession(_botId);
      final link = await _repo.issueConnectLink(_botId);
      emit(BotConnectReady(link));
    } on BotsFailure catch (f) {
      emit(BotConnectFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class BotConnectEvent {
  const BotConnectEvent();
}

class BotConnectStarted extends BotConnectEvent {
  const BotConnectStarted();
  @override
  bool operator ==(Object other) => other is BotConnectStarted;
  @override
  int get hashCode => (BotConnectStarted).hashCode;
}

// States --------------------------------------------------------------------

sealed class BotConnectState {
  const BotConnectState();
}

class BotConnectLoading extends BotConnectState {
  const BotConnectLoading();
  @override
  bool operator ==(Object other) => other is BotConnectLoading;
  @override
  int get hashCode => (BotConnectLoading).hashCode;
}

class BotConnectReady extends BotConnectState {
  const BotConnectReady(this.link);

  final ConnectLink link;

  @override
  bool operator ==(Object other) =>
      other is BotConnectReady && other.link == link;
  @override
  int get hashCode => link.hashCode;
}

class BotConnectFailed extends BotConnectState {
  const BotConnectFailed(this.failure);

  final BotsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is BotConnectFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}
