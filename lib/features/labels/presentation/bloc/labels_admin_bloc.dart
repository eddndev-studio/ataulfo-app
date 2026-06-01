import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/label.dart';
import '../../domain/failures/labels_failure.dart';
import '../../domain/repositories/labels_repository.dart';

/// Bloc de la sección de gestión de Labels internos (S10), org-scoped. A
/// diferencia del `LabelsBloc` de carga única que alimenta los selectores, este
/// posee el ciclo CRUD completo: lista, crea, edita y borra contra `/labels`.
///
/// No hay realtime para el catálogo interno (no se emite SSE de `/labels`),
/// así que el estado se mantiene con el resultado de cada mutación: create y
/// update insertan/reemplazan el Label devuelto por el backend; delete lo quita
/// de la lista. Una mutación fallida conserva el snapshot previo para que la
/// hoja abierta muestre el error sin perder la lista de fondo.
class LabelsAdminBloc extends Bloc<LabelsAdminEvent, LabelsAdminState> {
  LabelsAdminBloc({required LabelsRepository repo})
    : _repo = repo,
      super(const LabelsAdminLoading()) {
    on<LabelsAdminLoadRequested>(_onLoad);
    on<LabelsAdminRefreshRequested>(_onRefresh);
    on<LabelsAdminCreateRequested>(_onCreate);
    on<LabelsAdminUpdateRequested>(_onUpdate);
    on<LabelsAdminDeleteRequested>(_onDelete);
  }

  final LabelsRepository _repo;

  Future<void> _onLoad(
    LabelsAdminLoadRequested event,
    Emitter<LabelsAdminState> emit,
  ) async {
    if (state is! LabelsAdminLoading) {
      emit(const LabelsAdminLoading());
    }
    try {
      final labels = await _repo.listLabels();
      emit(LabelsAdminLoaded(labels: labels, isRefreshing: false));
    } on LabelsFailure catch (f) {
      emit(LabelsAdminFailed(f));
    }
  }

  Future<void> _onRefresh(
    LabelsAdminRefreshRequested event,
    Emitter<LabelsAdminState> emit,
  ) async {
    final current = state;
    if (current is! LabelsAdminLoaded) {
      add(const LabelsAdminLoadRequested());
      return;
    }
    emit(LabelsAdminLoaded(labels: current.labels, isRefreshing: true));
    try {
      final labels = await _repo.listLabels();
      emit(LabelsAdminLoaded(labels: labels, isRefreshing: false));
    } on LabelsFailure catch (f) {
      emit(LabelsAdminFailed(f));
    }
  }

  Future<void> _onCreate(
    LabelsAdminCreateRequested event,
    Emitter<LabelsAdminState> emit,
  ) async {
    await _runMutation(emit, (snapshot) async {
      final created = await _repo.createLabel(
        name: event.name,
        color: event.color,
        description: event.description,
      );
      return _upsert(snapshot, created);
    });
  }

  Future<void> _onUpdate(
    LabelsAdminUpdateRequested event,
    Emitter<LabelsAdminState> emit,
  ) async {
    await _runMutation(emit, (snapshot) async {
      final updated = await _repo.updateLabel(
        id: event.id,
        name: event.name,
        color: event.color,
        description: event.description,
      );
      return _upsert(snapshot, updated);
    });
  }

  Future<void> _onDelete(
    LabelsAdminDeleteRequested event,
    Emitter<LabelsAdminState> emit,
  ) async {
    await _runMutation(emit, (snapshot) async {
      await _repo.deleteLabel(id: event.id);
      return snapshot.where((l) => l.id != event.id).toList(growable: false);
    });
  }

  /// Orquesta una mutación del catálogo reusando el último snapshot válido
  /// (`Loaded` o `MutationFailed`). Desde `Loading`/`Mutating`/`Failed` ignora:
  /// no hay una lista fiable sobre la que aplicar el resultado.
  Future<void> _runMutation(
    Emitter<LabelsAdminState> emit,
    Future<List<Label>> Function(List<Label> snapshot) mutate,
  ) async {
    final current = state;
    final List<Label> snapshot;
    if (current is LabelsAdminLoaded) {
      snapshot = current.labels;
    } else if (current is LabelsAdminMutationFailed) {
      snapshot = current.labels;
    } else {
      return;
    }

    emit(LabelsAdminMutating(snapshot));
    try {
      final next = await mutate(snapshot);
      emit(LabelsAdminLoaded(labels: next, isRefreshing: false));
    } on LabelsFailure catch (f) {
      emit(LabelsAdminMutationFailed(snapshot, f));
    }
  }

  static List<Label> _upsert(List<Label> list, Label label) {
    final out = List<Label>.of(list);
    final i = out.indexWhere((l) => l.id == label.id);
    if (i >= 0) {
      out[i] = label;
    } else {
      out.add(label);
    }
    return out;
  }
}

// Events --------------------------------------------------------------------

sealed class LabelsAdminEvent {
  const LabelsAdminEvent();
}

class LabelsAdminLoadRequested extends LabelsAdminEvent {
  const LabelsAdminLoadRequested();
  @override
  bool operator ==(Object other) => other is LabelsAdminLoadRequested;
  @override
  int get hashCode => (LabelsAdminLoadRequested).hashCode;
}

class LabelsAdminRefreshRequested extends LabelsAdminEvent {
  const LabelsAdminRefreshRequested();
  @override
  bool operator ==(Object other) => other is LabelsAdminRefreshRequested;
  @override
  int get hashCode => (LabelsAdminRefreshRequested).hashCode;
}

class LabelsAdminCreateRequested extends LabelsAdminEvent {
  const LabelsAdminCreateRequested({
    required this.name,
    required this.color,
    required this.description,
  });

  final String name;
  final String color;
  final String description;

  @override
  bool operator ==(Object other) =>
      other is LabelsAdminCreateRequested &&
      other.name == name &&
      other.color == color &&
      other.description == description;
  @override
  int get hashCode => Object.hash(name, color, description);
}

class LabelsAdminUpdateRequested extends LabelsAdminEvent {
  const LabelsAdminUpdateRequested({
    required this.id,
    required this.name,
    required this.color,
    required this.description,
  });

  final String id;
  final String name;
  final String color;
  final String description;

  @override
  bool operator ==(Object other) =>
      other is LabelsAdminUpdateRequested &&
      other.id == id &&
      other.name == name &&
      other.color == color &&
      other.description == description;
  @override
  int get hashCode => Object.hash(id, name, color, description);
}

class LabelsAdminDeleteRequested extends LabelsAdminEvent {
  const LabelsAdminDeleteRequested({required this.id});

  final String id;

  @override
  bool operator ==(Object other) =>
      other is LabelsAdminDeleteRequested && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

// States --------------------------------------------------------------------

sealed class LabelsAdminState {
  const LabelsAdminState();
}

class LabelsAdminLoading extends LabelsAdminState {
  const LabelsAdminLoading();
  @override
  bool operator ==(Object other) => other is LabelsAdminLoading;
  @override
  int get hashCode => (LabelsAdminLoading).hashCode;
}

class LabelsAdminLoaded extends LabelsAdminState {
  const LabelsAdminLoaded({required this.labels, required this.isRefreshing});

  final List<Label> labels;

  /// Hay un refresh en vuelo (spinner sutil; la lista sigue visible).
  final bool isRefreshing;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LabelsAdminLoaded) return false;
    if (other.isRefreshing != isRefreshing) return false;
    return _listEq(other.labels, labels);
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(labels), isRefreshing);
}

class LabelsAdminFailed extends LabelsAdminState {
  const LabelsAdminFailed(this.failure);

  final LabelsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is LabelsAdminFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}

/// Una mutación está en vuelo. Lleva el snapshot vigente para que la lista siga
/// visible mientras la hoja dibuja su spinner; al terminar pasa a `Loaded`
/// (éxito) o `MutationFailed`.
class LabelsAdminMutating extends LabelsAdminState {
  const LabelsAdminMutating(this.labels);

  final List<Label> labels;

  @override
  bool operator ==(Object other) =>
      other is LabelsAdminMutating && _listEq(other.labels, labels);
  @override
  int get hashCode => Object.hashAll(labels);
}

/// Mutación fallida que preserva el snapshot pre-mutación. La hoja abierta
/// interpreta el failure y lo muestra; el resto de la pantalla sigue viendo la
/// lista. Una nueva mutación desde aquí reusa el snapshot como base.
class LabelsAdminMutationFailed extends LabelsAdminState {
  const LabelsAdminMutationFailed(this.labels, this.failure);

  final List<Label> labels;
  final LabelsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is LabelsAdminMutationFailed &&
      other.failure == failure &&
      _listEq(other.labels, labels);
  @override
  int get hashCode => Object.hash(failure, Object.hashAll(labels));
}

bool _listEq(List<Label> a, List<Label> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
