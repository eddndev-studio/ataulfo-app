import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../templates/domain/entities/variable_def.dart';
import '../../../templates/domain/failures/templates_failure.dart';
import '../../../templates/domain/repositories/templates_repository.dart';
import '../../domain/failures/bots_failure.dart';
import '../../domain/repositories/bots_repository.dart';

/// Bloc del editor de `variable_values` de un Bot (S04), página separada y
/// deep-linkable. Cross-feature: combina `BotsRepository` (la entidad Bot, con
/// su `version` para el CAS, y el `PUT`) y `TemplatesRepository` (las
/// definiciones de variables de la plantilla ligada, que siembran el form).
///
/// **MAJOR 2 — trampa de versión doble.** Como es una página aparte del
/// `BotDetailBloc`, NO hereda el Bot cargado: lo resuelve él mismo. La carga
/// trae DOS versiones distintas — la del Bot (de `getVariables`) y la del
/// Template (de `listVarDefs`). El `PUT` DEBE enviar la del **BOT**; enviar la
/// del template provocaría un 409 espurio o, peor, pisaría el CAS. El estado
/// `Loaded` lleva `botVersion` y el save lo usa siempre.
///
/// **Precarga (replace autoritativo).** `getVariables` (`GET
/// /bots/:id/variables`, ADMIN+) devuelve los overrides ya guardados, la
/// `version` del Bot (CAS consistente con esos valores) y el `templateId`. El
/// form los PRECARGA: un campo con override guardado lo muestra; uno sin
/// override arranca vacío con el default del template como placeholder. El
/// `PUT` REEMPLAZA por completo (el form representa el set deseado entero), así
/// que vaciar un campo elimina su override y vaciar todo envía `{}` (jamás
/// `null`). Precargar también evita el borrado accidental de overrides al
/// reabrir-y-guardar.
class BotVariablesBloc extends Bloc<BotVariablesEvent, BotVariablesState> {
  BotVariablesBloc({
    required BotsRepository botsRepo,
    required TemplatesRepository templatesRepo,
    required String botId,
  }) : _botsRepo = botsRepo,
       _templatesRepo = templatesRepo,
       _botId = botId,
       super(const BotVariablesLoading()) {
    on<BotVariablesLoadRequested>(_onLoad);
    on<BotVariablesSaveRequested>(_onSave);
  }

  final BotsRepository _botsRepo;
  final TemplatesRepository _templatesRepo;
  final String _botId;

  Future<void> _onLoad(
    BotVariablesLoadRequested event,
    Emitter<BotVariablesState> emit,
  ) async {
    if (state is! BotVariablesLoading) {
      emit(const BotVariablesLoading());
    }
    try {
      // Secuencial a propósito: el `templateId` (y la `version` del bot para el
      // CAS, más los overrides ya guardados) salen de `getVariables`, así la
      // página es deep-linkable sin pasarle el templateId por la ruta.
      final snap = await _botsRepo.getVariables(_botId);
      final result = await _templatesRepo.listVarDefs(snap.templateId);
      if (result.defs.isEmpty) {
        emit(const BotVariablesEmpty());
        return;
      }
      emit(
        BotVariablesLoaded(
          defs: result.defs,
          botVersion: snap.version,
          currentValues: snap.values,
        ),
      );
    } on BotsFailure catch (f) {
      emit(BotVariablesFailed(_botsError(f)));
    } on TemplatesFailure catch (f) {
      emit(BotVariablesFailed(_templatesError(f)));
    }
  }

  Future<void> _onSave(
    BotVariablesSaveRequested event,
    Emitter<BotVariablesState> emit,
  ) async {
    final current = state;
    final List<VariableDef> defs;
    final int botVersion;
    final Map<String, String> currentValues;
    if (current is BotVariablesLoaded) {
      defs = current.defs;
      botVersion = current.botVersion;
      currentValues = current.currentValues;
    } else if (current is BotVariablesSaveFailed) {
      defs = current.defs;
      botVersion = current.botVersion;
      currentValues = current.currentValues;
    } else {
      return;
    }

    emit(
      BotVariablesSaving(
        defs: defs,
        botVersion: botVersion,
        currentValues: currentValues,
      ),
    );
    try {
      // MAJOR 2: `botVersion` (de `byId`), NUNCA la versión del template.
      // `event.values` ya viene con keys ⊆ defs (lo garantiza el form) y `{}`
      // cuando no hay overrides (el DTO lo serializa como objeto vacío, no null).
      await _botsRepo.update(
        id: _botId,
        version: botVersion,
        variableValues: event.values,
      );
      emit(const BotVariablesSaved());
    } on BotsFailure catch (f) {
      emit(
        BotVariablesSaveFailed(
          defs: defs,
          botVersion: botVersion,
          currentValues: currentValues,
          failure: f,
        ),
      );
    }
  }

  static BotVariablesLoadError _botsError(BotsFailure f) => switch (f) {
    BotsNotFoundFailure() => BotVariablesLoadError.notFound,
    BotsForbiddenFailure() => BotVariablesLoadError.forbidden,
    BotsNetworkFailure() ||
    BotsTimeoutFailure() => BotVariablesLoadError.network,
    _ => BotVariablesLoadError.generic,
  };

  static BotVariablesLoadError _templatesError(TemplatesFailure f) =>
      switch (f) {
        TemplatesNotFoundFailure() => BotVariablesLoadError.notFound,
        TemplatesForbiddenFailure() => BotVariablesLoadError.forbidden,
        TemplatesNetworkFailure() ||
        TemplatesTimeoutFailure() => BotVariablesLoadError.network,
        _ => BotVariablesLoadError.generic,
      };
}

/// Causa normalizada de un fallo de carga (unifica `BotsFailure` de `byId` y
/// `TemplatesFailure` de `listVarDefs` en un set accionable por la UI).
enum BotVariablesLoadError { notFound, forbidden, network, generic }

// Events --------------------------------------------------------------------

sealed class BotVariablesEvent {
  const BotVariablesEvent();
}

class BotVariablesLoadRequested extends BotVariablesEvent {
  const BotVariablesLoadRequested();
  @override
  bool operator ==(Object other) => other is BotVariablesLoadRequested;
  @override
  int get hashCode => (BotVariablesLoadRequested).hashCode;
}

/// Guarda los overrides. `values` lleva SÓLO las keys que el operador tocó
/// (subset de defs); `{}` = sin overrides (replace a vacío).
class BotVariablesSaveRequested extends BotVariablesEvent {
  const BotVariablesSaveRequested(this.values);

  final Map<String, String> values;

  @override
  bool operator ==(Object other) =>
      other is BotVariablesSaveRequested && _mapEq(other.values, values);
  @override
  int get hashCode => Object.hashAll(<Object?>[
    for (final e in values.entries) ...<Object?>[e.key, e.value],
  ]);
}

// States --------------------------------------------------------------------

sealed class BotVariablesState {
  const BotVariablesState();
}

class BotVariablesLoading extends BotVariablesState {
  const BotVariablesLoading();
  @override
  bool operator ==(Object other) => other is BotVariablesLoading;
  @override
  int get hashCode => (BotVariablesLoading).hashCode;
}

/// El template no declara variables: nada que editar.
class BotVariablesEmpty extends BotVariablesState {
  const BotVariablesEmpty();
  @override
  bool operator ==(Object other) => other is BotVariablesEmpty;
  @override
  int get hashCode => (BotVariablesEmpty).hashCode;
}

class BotVariablesFailed extends BotVariablesState {
  const BotVariablesFailed(this.error);

  final BotVariablesLoadError error;

  @override
  bool operator ==(Object other) =>
      other is BotVariablesFailed && other.error == error;
  @override
  int get hashCode => error.hashCode;
}

/// Form listo. Lleva las defs (para pintar un campo por variable), la
/// `botVersion` (CAS del save, usada SIEMPRE) y los `currentValues` (overrides
/// ya guardados que el form PRECARGA por nombre de variable).
class BotVariablesLoaded extends BotVariablesState {
  const BotVariablesLoaded({
    required this.defs,
    required this.botVersion,
    this.currentValues = const <String, String>{},
  });

  final List<VariableDef> defs;
  final int botVersion;
  final Map<String, String> currentValues;

  @override
  bool operator ==(Object other) =>
      other is BotVariablesLoaded &&
      other.botVersion == botVersion &&
      _listEq(other.defs, defs) &&
      _mapEq(other.currentValues, currentValues);
  @override
  int get hashCode =>
      Object.hash(Object.hashAll(defs), botVersion, _mapHash(currentValues));
}

class BotVariablesSaving extends BotVariablesState {
  const BotVariablesSaving({
    required this.defs,
    required this.botVersion,
    this.currentValues = const <String, String>{},
  });

  final List<VariableDef> defs;
  final int botVersion;
  final Map<String, String> currentValues;

  @override
  bool operator ==(Object other) =>
      other is BotVariablesSaving &&
      other.botVersion == botVersion &&
      _listEq(other.defs, defs) &&
      _mapEq(other.currentValues, currentValues);
  @override
  int get hashCode =>
      Object.hash(Object.hashAll(defs), botVersion, _mapHash(currentValues));
}

/// Save fallido: conserva defs+version+currentValues para que el form siga
/// editable, precargado y reintente.
class BotVariablesSaveFailed extends BotVariablesState {
  const BotVariablesSaveFailed({
    required this.defs,
    required this.botVersion,
    required this.failure,
    this.currentValues = const <String, String>{},
  });

  final List<VariableDef> defs;
  final int botVersion;
  final Map<String, String> currentValues;
  final BotsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is BotVariablesSaveFailed &&
      other.botVersion == botVersion &&
      other.failure == failure &&
      _listEq(other.defs, defs) &&
      _mapEq(other.currentValues, currentValues);
  @override
  int get hashCode => Object.hash(
    Object.hashAll(defs),
    botVersion,
    failure,
    _mapHash(currentValues),
  );
}

/// Save exitoso (transitorio): la página hace pop al detalle.
class BotVariablesSaved extends BotVariablesState {
  const BotVariablesSaved();
  @override
  bool operator ==(Object other) => other is BotVariablesSaved;
  @override
  int get hashCode => (BotVariablesSaved).hashCode;
}

bool _listEq(List<VariableDef> a, List<VariableDef> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEq(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

// XOR sobre las entradas: independiente del orden de iteración, así dos mapas
// iguales (mismas entradas) producen el mismo hashCode aunque difiera el orden.
int _mapHash(Map<String, String> m) {
  var h = 0;
  for (final e in m.entries) {
    h ^= Object.hash(e.key, e.value);
  }
  return h;
}
