import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../../domain/repositories/bots_repository.dart';

/// Bloc del detalle de un Bot (S04). Vida del bloc atada a la ruta
/// `/bots/:id`: se construye con el ID y arranca en `Loading` para que la
/// página tenga spinner desde el primer frame (sin flash de Initial).
///
/// Graduado de loader puro a CRUD-bloc de UNA entidad: además de cargar,
/// muta el Bot vía `PUT /bots/:id` con CAS optimista. Rastrea la `version`
/// del último GET en el snapshot `Loaded`/`MutationFailed` y la envía en
/// cada PUT; nunca la hardcodea. Una mutación fallida conserva el snapshot
/// para que la UI siga mostrando el bot mientras dibuja el error.
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
    on<BotDetailUpdateRequested>(_onUpdate);
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

  Future<void> _onUpdate(
    BotDetailUpdateRequested event,
    Emitter<BotDetailState> emit,
  ) async {
    await _runMutation(
      emit,
      (snapshot) => _repo.update(
        id: _id,
        version: snapshot.version,
        name: event.name,
        paused: event.paused,
        aiDisabled: event.aiDisabled,
      ),
    );
  }

  /// Orquesta una mutación reusando el último snapshot válido (`Loaded` o
  /// `MutationFailed`). Desde `Loading`/`Mutating`/`Failed` ignora: no hay un
  /// Bot fiable sobre el que aplicar versión + resultado.
  ///
  /// En 409 (`BotsConflictFailure`) la versión enviada quedó atrás. Se hace
  /// un re-GET automático para refrescar el snapshot (y su versión) ANTES de
  /// emitir el fallo: así el copy "estaba desactualizada, refrescamos" queda
  /// visible Y un reintento usa la versión correcta. Si el re-GET también
  /// falla, se conserva el snapshot previo con el failure de conflicto.
  Future<void> _runMutation(
    Emitter<BotDetailState> emit,
    Future<Bot> Function(Bot snapshot) mutate,
  ) async {
    final current = state;
    final Bot snapshot;
    if (current is BotDetailLoaded) {
      snapshot = current.bot;
    } else if (current is BotDetailMutationFailed) {
      snapshot = current.bot;
    } else {
      return;
    }

    emit(BotDetailMutating(snapshot));
    try {
      final next = await mutate(snapshot);
      emit(BotDetailLoaded(next));
    } on BotsConflictFailure catch (f) {
      try {
        final fresh = await _repo.byId(_id);
        emit(BotDetailMutationFailed(fresh, f));
      } on BotsFailure {
        emit(BotDetailMutationFailed(snapshot, f));
      }
    } on BotsFailure catch (f) {
      emit(BotDetailMutationFailed(snapshot, f));
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

/// Pide un `PUT /bots/:id` tristate: los campos null se omiten ("no tocar").
/// La `version` NO viaja en el evento — la toma del snapshot vigente en el
/// bloc (CAS). Lo despachan los controles de detalle (pausar, IA, renombrar).
class BotDetailUpdateRequested extends BotDetailEvent {
  const BotDetailUpdateRequested({this.name, this.paused, this.aiDisabled});

  final String? name;
  final bool? paused;
  final bool? aiDisabled;

  @override
  bool operator ==(Object other) =>
      other is BotDetailUpdateRequested &&
      other.name == name &&
      other.paused == paused &&
      other.aiDisabled == aiDisabled;
  @override
  int get hashCode => Object.hash(name, paused, aiDisabled);
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

/// Una mutación está en vuelo. Lleva el snapshot vigente para que la página
/// siga mostrando el bot (controles inhabilitados) mientras termina; al
/// terminar pasa a `Loaded` (éxito) o `MutationFailed`.
class BotDetailMutating extends BotDetailState {
  const BotDetailMutating(this.bot);

  final Bot bot;

  @override
  bool operator ==(Object other) =>
      other is BotDetailMutating && other.bot == bot;
  @override
  int get hashCode => bot.hashCode;
}

/// Mutación fallida que preserva un snapshot del bot. La página sigue
/// mostrándolo y dibuja el error; una nueva mutación desde aquí reusa este
/// snapshot (y su versión) como base. Tras un 409 el snapshot ya viene
/// refrescado por el re-GET.
class BotDetailMutationFailed extends BotDetailState {
  const BotDetailMutationFailed(this.bot, this.failure);

  final Bot bot;
  final BotsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is BotDetailMutationFailed &&
      other.bot == bot &&
      other.failure == failure;
  @override
  int get hashCode => Object.hash(bot, failure);
}
