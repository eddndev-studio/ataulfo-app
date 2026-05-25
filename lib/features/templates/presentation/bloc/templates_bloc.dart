import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../../domain/repositories/templates_repository.dart';

/// Bloc del listado de templates (S03). Es feature-local: la composición la
/// sube el route builder de `/home` sobre `BlocProvider`. El estado expone
/// `isRefreshing` dentro de `TemplatesLoaded` para que el pull-to-refresh
/// no oculte la lista mientras se refresca.
class TemplatesBloc extends Bloc<TemplatesEvent, TemplatesState> {
  TemplatesBloc(this._repo) : super(const TemplatesInitial()) {
    on<TemplatesLoadRequested>(_onLoad);
    on<TemplatesRefreshRequested>(_onRefresh);
  }

  final TemplatesRepository _repo;

  Future<void> _onLoad(
    TemplatesLoadRequested event,
    Emitter<TemplatesState> emit,
  ) async {
    emit(const TemplatesLoading());
    try {
      final items = await _repo.list();
      emit(TemplatesLoaded(items: items, isRefreshing: false));
    } on TemplatesFailure catch (f) {
      emit(TemplatesFailed(f));
    }
  }

  Future<void> _onRefresh(
    TemplatesRefreshRequested event,
    Emitter<TemplatesState> emit,
  ) async {
    final current = state;
    if (current is! TemplatesLoaded) {
      // Sin lista previa, un refresh degenera al primer load — el widget
      // de la pantalla no debería disparar refresh desde estados ajenos,
      // pero si pasa, el bloc no pierde tiempo en una transición artificial.
      add(const TemplatesLoadRequested());
      return;
    }
    emit(TemplatesLoaded(items: current.items, isRefreshing: true));
    try {
      final items = await _repo.list();
      emit(TemplatesLoaded(items: items, isRefreshing: false));
    } on TemplatesFailure catch (f) {
      emit(TemplatesFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class TemplatesEvent {
  const TemplatesEvent();
}

class TemplatesLoadRequested extends TemplatesEvent {
  const TemplatesLoadRequested();
  @override
  bool operator ==(Object other) => other is TemplatesLoadRequested;
  @override
  int get hashCode => (TemplatesLoadRequested).hashCode;
}

class TemplatesRefreshRequested extends TemplatesEvent {
  const TemplatesRefreshRequested();
  @override
  bool operator ==(Object other) => other is TemplatesRefreshRequested;
  @override
  int get hashCode => (TemplatesRefreshRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class TemplatesState {
  const TemplatesState();
}

class TemplatesInitial extends TemplatesState {
  const TemplatesInitial();
  @override
  bool operator ==(Object other) => other is TemplatesInitial;
  @override
  int get hashCode => (TemplatesInitial).hashCode;
}

class TemplatesLoading extends TemplatesState {
  const TemplatesLoading();
  @override
  bool operator ==(Object other) => other is TemplatesLoading;
  @override
  int get hashCode => (TemplatesLoading).hashCode;
}

class TemplatesLoaded extends TemplatesState {
  const TemplatesLoaded({required this.items, required this.isRefreshing});

  final List<Template> items;
  final bool isRefreshing;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TemplatesLoaded) return false;
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

class TemplatesFailed extends TemplatesState {
  const TemplatesFailed(this.failure);

  final TemplatesFailure failure;

  @override
  bool operator ==(Object other) =>
      other is TemplatesFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
