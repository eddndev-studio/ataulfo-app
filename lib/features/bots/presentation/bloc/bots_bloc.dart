import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../../domain/repositories/bots_repository.dart';

/// Bloc del listado de bots (S04). Es feature-local: la composición la sube
/// el shell sobre `BlocProvider`. El estado expone `isRefreshing` dentro de
/// `BotsLoaded` para que el pull-to-refresh no oculte la lista mientras se
/// refresca.
class BotsBloc extends Bloc<BotsEvent, BotsState> {
  BotsBloc(this._repo) : super(const BotsInitial()) {
    on<BotsLoadRequested>(_onLoad);
    on<BotsRefreshRequested>(_onRefresh);
  }

  final BotsRepository _repo;

  Future<void> _onLoad(BotsLoadRequested event, Emitter<BotsState> emit) async {
    emit(const BotsLoading());
    try {
      final items = await _repo.list();
      emit(BotsLoaded(items: items, isRefreshing: false));
    } on BotsFailure catch (f) {
      emit(BotsFailed(f));
    }
  }

  Future<void> _onRefresh(
    BotsRefreshRequested event,
    Emitter<BotsState> emit,
  ) async {
    final current = state;
    if (current is! BotsLoaded) {
      // Sin lista previa, un refresh degenera al primer load — el widget
      // de la pantalla no debería disparar refresh desde estados ajenos,
      // pero si pasa, el bloc no pierde tiempo en una transición artificial.
      add(const BotsLoadRequested());
      return;
    }
    emit(BotsLoaded(items: current.items, isRefreshing: true));
    try {
      final items = await _repo.list();
      emit(BotsLoaded(items: items, isRefreshing: false));
    } on BotsFailure catch (f) {
      emit(BotsFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class BotsEvent {
  const BotsEvent();
}

class BotsLoadRequested extends BotsEvent {
  const BotsLoadRequested();
  @override
  bool operator ==(Object other) => other is BotsLoadRequested;
  @override
  int get hashCode => (BotsLoadRequested).hashCode;
}

class BotsRefreshRequested extends BotsEvent {
  const BotsRefreshRequested();
  @override
  bool operator ==(Object other) => other is BotsRefreshRequested;
  @override
  int get hashCode => (BotsRefreshRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class BotsState {
  const BotsState();
}

class BotsInitial extends BotsState {
  const BotsInitial();
  @override
  bool operator ==(Object other) => other is BotsInitial;
  @override
  int get hashCode => (BotsInitial).hashCode;
}

class BotsLoading extends BotsState {
  const BotsLoading();
  @override
  bool operator ==(Object other) => other is BotsLoading;
  @override
  int get hashCode => (BotsLoading).hashCode;
}

class BotsLoaded extends BotsState {
  const BotsLoaded({required this.items, required this.isRefreshing});

  final List<Bot> items;
  final bool isRefreshing;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BotsLoaded) return false;
    if (other.isRefreshing != isRefreshing) return false;
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(items), isRefreshing);
}

class BotsFailed extends BotsState {
  const BotsFailed(this.failure);

  final BotsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is BotsFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
