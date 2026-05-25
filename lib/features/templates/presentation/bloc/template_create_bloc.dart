import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../../domain/repositories/templates_repository.dart';

/// Bloc del flujo "crear plantilla". Mapea la acción del usuario a
/// `repo.create(name)` y expone estados que la UI consume directamente.
///
/// Las failures se exponen tal cual (sin enum intermedio): la UI hace el
/// switch exhaustivo sobre `TemplatesFailure` y elige copy. El sealed
/// fuerza al compilador a cubrir las variantes.
class TemplateCreateBloc
    extends Bloc<TemplateCreateEvent, TemplateCreateState> {
  TemplateCreateBloc({required TemplatesRepository repo})
    : _repo = repo,
      super(const TemplateCreateInitial()) {
    on<TemplateCreateSubmitted>(_onSubmitted);
  }

  final TemplatesRepository _repo;

  Future<void> _onSubmitted(
    TemplateCreateSubmitted event,
    Emitter<TemplateCreateState> emit,
  ) async {
    emit(const TemplateCreateSubmitting());
    try {
      final tpl = await _repo.create(event.name);
      emit(TemplateCreateSucceeded(tpl));
    } on TemplatesFailure catch (e) {
      emit(TemplateCreateFailed(e));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class TemplateCreateEvent {
  const TemplateCreateEvent();
}

class TemplateCreateSubmitted extends TemplateCreateEvent {
  const TemplateCreateSubmitted({required this.name});

  final String name;

  @override
  bool operator ==(Object other) =>
      other is TemplateCreateSubmitted && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

// States --------------------------------------------------------------------

sealed class TemplateCreateState {
  const TemplateCreateState();
}

class TemplateCreateInitial extends TemplateCreateState {
  const TemplateCreateInitial();

  @override
  bool operator ==(Object other) => other is TemplateCreateInitial;

  @override
  int get hashCode => (TemplateCreateInitial).hashCode;
}

class TemplateCreateSubmitting extends TemplateCreateState {
  const TemplateCreateSubmitting();

  @override
  bool operator ==(Object other) => other is TemplateCreateSubmitting;

  @override
  int get hashCode => (TemplateCreateSubmitting).hashCode;
}

class TemplateCreateSucceeded extends TemplateCreateState {
  const TemplateCreateSucceeded(this.template);

  final Template template;

  @override
  bool operator ==(Object other) =>
      other is TemplateCreateSucceeded && other.template == template;

  @override
  int get hashCode => template.hashCode;
}

class TemplateCreateFailed extends TemplateCreateState {
  const TemplateCreateFailed(this.failure);

  final TemplatesFailure failure;

  @override
  bool operator ==(Object other) =>
      other is TemplateCreateFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
