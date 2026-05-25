import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../../domain/repositories/templates_repository.dart';

/// Bloc del detalle de una Template (S03). Vida del bloc atada a la ruta
/// `/templates/:id`: se construye con el ID y arranca en `Loading` para que
/// la página tenga spinner desde el primer frame (sin flash de Initial).
///
/// Hoy NO consume seed desde el `TemplatesBloc` del listado — siempre golpea
/// `repo.byId`. Cuando aterrice la cache (RFC-0001), el repositorio
/// devolverá la template local instantánea y orquestará el refetch contra
/// el backend; ese cambio queda confinado a la capa data.
class TemplateDetailBloc
    extends Bloc<TemplateDetailEvent, TemplateDetailState> {
  TemplateDetailBloc({required TemplatesRepository repo, required String id})
    : _repo = repo,
      _id = id,
      super(const TemplateDetailLoading()) {
    on<TemplateDetailLoadRequested>(_onLoad);
  }

  final TemplatesRepository _repo;
  final String _id;

  Future<void> _onLoad(
    TemplateDetailLoadRequested event,
    Emitter<TemplateDetailState> emit,
  ) async {
    // Sólo emitimos Loading si venimos de un estado distinto (retry desde
    // Failed o Loaded). Si ya estamos en Loading — caso del primer load
    // post-construcción — evitar la emisión duplicada mantiene el stream
    // limpio para los suscriptores.
    if (state is! TemplateDetailLoading) {
      emit(const TemplateDetailLoading());
    }
    try {
      final tpl = await _repo.byId(_id);
      emit(TemplateDetailLoaded(tpl));
    } on TemplatesFailure catch (f) {
      emit(TemplateDetailFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class TemplateDetailEvent {
  const TemplateDetailEvent();
}

class TemplateDetailLoadRequested extends TemplateDetailEvent {
  const TemplateDetailLoadRequested();
  @override
  bool operator ==(Object other) => other is TemplateDetailLoadRequested;
  @override
  int get hashCode => (TemplateDetailLoadRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class TemplateDetailState {
  const TemplateDetailState();
}

class TemplateDetailLoading extends TemplateDetailState {
  const TemplateDetailLoading();
  @override
  bool operator ==(Object other) => other is TemplateDetailLoading;
  @override
  int get hashCode => (TemplateDetailLoading).hashCode;
}

class TemplateDetailLoaded extends TemplateDetailState {
  const TemplateDetailLoaded(this.template);

  final Template template;

  @override
  bool operator ==(Object other) =>
      other is TemplateDetailLoaded && other.template == template;
  @override
  int get hashCode => template.hashCode;
}

class TemplateDetailFailed extends TemplateDetailState {
  const TemplateDetailFailed(this.failure);

  final TemplatesFailure failure;

  @override
  bool operator ==(Object other) =>
      other is TemplateDetailFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}
