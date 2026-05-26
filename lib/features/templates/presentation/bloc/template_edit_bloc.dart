import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../../domain/repositories/templates_repository.dart';

/// Bloc del flujo "editar plantilla" — TE1 cubre name + systemPrompt.
///
/// Arranca en `TemplateEditLoading` (sin flash de Initial) y se construye
/// con el id; el caller dispara `TemplateEditLoadRequested` al montarse
/// (mismo patrón que TemplateDetailBloc + BotDetailBloc). El submit
/// preserva el `Template` cargado en los estados Submitting/SubmitFailed
/// para que la UI pueda re-renderear el form con los valores del
/// operador aún si el backend rechaza el PUT.
///
/// `Succeeded(updated)` termina la vida del bloc: la página debe navegar
/// fuera (pushReplacement al detail) en lugar de volver a `Editing`.
class TemplateEditBloc extends Bloc<TemplateEditEvent, TemplateEditState> {
  TemplateEditBloc({required TemplatesRepository repo, required String id})
    : _repo = repo,
      _id = id,
      super(const TemplateEditLoading()) {
    on<TemplateEditLoadRequested>(_onLoad);
    on<TemplateEditSubmitted>(_onSubmit);
  }

  final TemplatesRepository _repo;
  final String _id;

  Future<void> _onLoad(
    TemplateEditLoadRequested event,
    Emitter<TemplateEditState> emit,
  ) async {
    // No re-emite Loading si ya estamos ahí (post-construcción): evita un
    // doble emit visible. El retry desde LoadFailed sí pasa por Loading
    // para señalar la nueva intención al usuario.
    if (state is! TemplateEditLoading) {
      emit(const TemplateEditLoading());
    }
    try {
      final tpl = await _repo.byId(_id);
      emit(TemplateEditEditing(tpl));
    } on TemplatesFailure catch (f) {
      emit(TemplateEditLoadFailed(f));
    }
  }

  Future<void> _onSubmit(
    TemplateEditSubmitted event,
    Emitter<TemplateEditState> emit,
  ) async {
    // Submit sólo es legítimo desde Editing o SubmitFailed (retry); en
    // cualquier otro estado el caller está mal. Ignorar mantiene el bloc
    // estable.
    final current = state;
    final template = switch (current) {
      TemplateEditEditing(template: final t) => t,
      TemplateEditSubmitFailed(template: final t) => t,
      _ => null,
    };
    if (template == null) return;

    emit(TemplateEditSubmitting(template));
    try {
      // Submit reenvía el AIConfig provisto por el caller intacto al repo.
      // El form de edit construye el value object completo a partir de su
      // propio estado; el bloc no reconstruye ni clona campos. Antes (TE1
      // con form mínimo) el bloc preservaba 6 campos no-editables; con
      // el editor completo (TE3) la responsabilidad migra al caller.
      final updated = await _repo.update(
        id: _id,
        name: event.name,
        version: template.version,
        ai: event.ai,
      );
      emit(TemplateEditSucceeded(updated));
    } on TemplatesFailure catch (f) {
      emit(TemplateEditSubmitFailed(failure: f, template: template));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class TemplateEditEvent {
  const TemplateEditEvent();
}

class TemplateEditLoadRequested extends TemplateEditEvent {
  const TemplateEditLoadRequested();

  @override
  bool operator ==(Object other) => other is TemplateEditLoadRequested;

  @override
  int get hashCode => (TemplateEditLoadRequested).hashCode;
}

class TemplateEditSubmitted extends TemplateEditEvent {
  const TemplateEditSubmitted({required this.name, required this.ai});

  final String name;
  final AIConfig ai;

  @override
  bool operator ==(Object other) =>
      other is TemplateEditSubmitted && other.name == name && other.ai == ai;

  @override
  int get hashCode => Object.hash(name, ai);
}

// States --------------------------------------------------------------------

sealed class TemplateEditState {
  const TemplateEditState();
}

class TemplateEditLoading extends TemplateEditState {
  const TemplateEditLoading();

  @override
  bool operator ==(Object other) => other is TemplateEditLoading;

  @override
  int get hashCode => (TemplateEditLoading).hashCode;
}

class TemplateEditEditing extends TemplateEditState {
  const TemplateEditEditing(this.template);

  final Template template;

  @override
  bool operator ==(Object other) =>
      other is TemplateEditEditing && other.template == template;

  @override
  int get hashCode => template.hashCode;
}

class TemplateEditLoadFailed extends TemplateEditState {
  const TemplateEditLoadFailed(this.failure);

  final TemplatesFailure failure;

  @override
  bool operator ==(Object other) =>
      other is TemplateEditLoadFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

class TemplateEditSubmitting extends TemplateEditState {
  const TemplateEditSubmitting(this.template);

  final Template template;

  @override
  bool operator ==(Object other) =>
      other is TemplateEditSubmitting && other.template == template;

  @override
  int get hashCode => template.hashCode;
}

class TemplateEditSubmitFailed extends TemplateEditState {
  const TemplateEditSubmitFailed({
    required this.failure,
    required this.template,
  });

  final TemplatesFailure failure;
  final Template template;

  @override
  bool operator ==(Object other) =>
      other is TemplateEditSubmitFailed &&
      other.failure == failure &&
      other.template == template;

  @override
  int get hashCode => Object.hash(failure, template);
}

class TemplateEditSucceeded extends TemplateEditState {
  const TemplateEditSucceeded(this.template);

  final Template template;

  @override
  bool operator ==(Object other) =>
      other is TemplateEditSucceeded && other.template == template;

  @override
  int get hashCode => template.hashCode;
}
