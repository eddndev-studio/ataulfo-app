import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/label.dart';
import '../../domain/failures/labels_failure.dart';
import '../../domain/repositories/labels_repository.dart';

/// Bloc del catálogo de Labels internos (S10), org-scoped. Carga única
/// (`GET /labels`); lista vacía es válida (la org aún no creó labels).
/// Arranca en `Loading` para no flashear un estado intermedio cuando se
/// monta junto al sheet que lo consume.
///
/// Solo lectura: el CRUD de Labels vive en su propia sección. Aquí el
/// único uso es poblar el selector de etiqueta del editor de
/// disparadores LABEL — por eso un fallo cargando labels NO debe
/// arrastrar al resto del sheet (un disparador TEXT no consume este
/// bloc).
class LabelsBloc extends Bloc<LabelsEvent, LabelsState> {
  LabelsBloc({required LabelsRepository repo})
    : _repo = repo,
      super(const LabelsLoading()) {
    on<LabelsLoadRequested>(_onLoad);
  }

  final LabelsRepository _repo;

  Future<void> _onLoad(
    LabelsLoadRequested event,
    Emitter<LabelsState> emit,
  ) async {
    if (state is! LabelsLoading) {
      emit(const LabelsLoading());
    }
    try {
      final labels = await _repo.listLabels();
      emit(LabelsLoaded(labels));
    } on LabelsFailure catch (f) {
      emit(LabelsFailed(f));
    }
  }
}

sealed class LabelsEvent {
  const LabelsEvent();
}

/// Carga (o recarga, tras un error) el catálogo de labels.
class LabelsLoadRequested extends LabelsEvent {
  const LabelsLoadRequested();
}

sealed class LabelsState {
  const LabelsState();
}

class LabelsLoading extends LabelsState {
  const LabelsLoading();
  @override
  bool operator ==(Object other) => other is LabelsLoading;
  @override
  int get hashCode => (LabelsLoading).hashCode;
}

class LabelsLoaded extends LabelsState {
  const LabelsLoaded(this.labels);

  final List<Label> labels;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LabelsLoaded) return false;
    if (other.labels.length != labels.length) return false;
    for (var i = 0; i < labels.length; i++) {
      if (other.labels[i] != labels[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(labels);
}

class LabelsFailed extends LabelsState {
  const LabelsFailed(this.failure);

  final LabelsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is LabelsFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
