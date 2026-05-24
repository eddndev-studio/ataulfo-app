import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../../domain/repositories/bots_repository.dart';

/// Bloc del detalle de un Bot (S04). Vida del bloc atada a la ruta
/// `/bots/:id`: se construye con el ID y arranca en `Loading` para que la
/// página tenga spinner desde el primer frame (sin flash de Initial).
///
/// Hoy NO consume seed desde el `BotsBloc` del listado — siempre golpea
/// `repo.byId`. Cuando aterrice la cache (RFC-0001), el repositorio
/// devolverá el bot local instantáneo y orquestará el refetch contra el
/// backend; ese cambio queda confinado a la capa data.
class BotDetailBloc extends Bloc<BotDetailEvent, BotDetailState> {
  BotDetailBloc({required BotsRepository repo, required String id})
    : _repo = repo,
      _id = id,
      super(const BotDetailLoading()) {
    on<BotDetailLoadRequested>(_onLoad);
  }

  final BotsRepository _repo;
  final String _id;

  Future<void> _onLoad(
    BotDetailLoadRequested event,
    Emitter<BotDetailState> emit,
  ) async {
    // Sólo emitimos Loading si venimos de un estado distinto (retry desde
    // Failed o Loaded). Si ya estamos en Loading — caso del primer load
    // post-construcción — evitar la emisión duplicada mantiene el stream
    // limpio para los suscriptores.
    if (state is! BotDetailLoading) {
      emit(const BotDetailLoading());
    }
    try {
      final bot = await _repo.byId(_id);
      emit(BotDetailLoaded(bot));
    } on BotsFailure catch (f) {
      emit(BotDetailFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class BotDetailEvent {
  const BotDetailEvent();
}

class BotDetailLoadRequested extends BotDetailEvent {
  const BotDetailLoadRequested();
  @override
  bool operator ==(Object other) => other is BotDetailLoadRequested;
  @override
  int get hashCode => (BotDetailLoadRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class BotDetailState {
  const BotDetailState();
}

class BotDetailLoading extends BotDetailState {
  const BotDetailLoading();
  @override
  bool operator ==(Object other) => other is BotDetailLoading;
  @override
  int get hashCode => (BotDetailLoading).hashCode;
}

class BotDetailLoaded extends BotDetailState {
  const BotDetailLoaded(this.bot);

  final Bot bot;

  @override
  bool operator ==(Object other) =>
      other is BotDetailLoaded && other.bot == bot;
  @override
  int get hashCode => bot.hashCode;
}

class BotDetailFailed extends BotDetailState {
  const BotDetailFailed(this.failure);

  final BotsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is BotDetailFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}
