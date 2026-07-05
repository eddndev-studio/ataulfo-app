// Eventos del FlowDetailBloc. Parte de la librería del bloc: los tipos
// sellados del wire de eventos viven en su archivo hermano para que la
// unidad quede legible sin inflar el archivo del orquestador.
part of 'flow_detail_bloc.dart';

sealed class FlowDetailEvent {
  const FlowDetailEvent();
}

class FlowDetailLoadRequested extends FlowDetailEvent {
  const FlowDetailLoadRequested();
  @override
  bool operator ==(Object other) => other is FlowDetailLoadRequested;
  @override
  int get hashCode => (FlowDetailLoadRequested).hashCode;
}

/// Pide refrescar cabecera + siblings CONSERVANDO el snapshot visible
/// (nunca Loading). Lo dispara el hub al volver de una subpágina que
/// pudo mutar el flujo, para que la `version` del CAS no quede stale.
class FlowDetailRefreshRequested extends FlowDetailEvent {
  const FlowDetailRefreshRequested();
  @override
  bool operator ==(Object other) => other is FlowDetailRefreshRequested;
  @override
  int get hashCode => (FlowDetailRefreshRequested).hashCode;
}

/// Pide renombrar el flujo. El bloc arma el PUT replace-completo con el
/// snapshot (isActive/gates intactos) y la `version` del CAS.
class FlowDetailRenameRequested extends FlowDetailEvent {
  const FlowDetailRenameRequested(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      other is FlowDetailRenameRequested && other.name == name;
  @override
  int get hashCode => name.hashCode;
}

/// Pide pausar (`false`) o activar (`true`) el flujo. Mismo PUT
/// replace-completo que el rename, con solo `isActive` cambiado.
class FlowDetailSetActiveRequested extends FlowDetailEvent {
  const FlowDetailSetActiveRequested(this.isActive);

  final bool isActive;

  @override
  bool operator ==(Object other) =>
      other is FlowDetailSetActiveRequested && other.isActive == isActive;
  @override
  int get hashCode => isActive.hashCode;
}

/// Pide eliminar el flujo (cascada de pasos y disparadores en el
/// backend). En éxito el bloc emite [FlowDetailDeleted]; la página
/// navega de regreso a la lista.
class FlowDetailDeleteRequested extends FlowDetailEvent {
  const FlowDetailDeleteRequested();
  @override
  bool operator ==(Object other) => other is FlowDetailDeleteRequested;
  @override
  int get hashCode => (FlowDetailDeleteRequested).hashCode;
}

/// Pide guardar la configuración del flow (gates + allowlist de IA).
/// `name` e `isActive` no viajan: el bloc los toma del snapshot Loaded
/// y los reenvía intactos en el PUT replace-completo. La version del
/// CAS también sale del snapshot. `aiInvocable` SÍ viaja: es parte del
/// form de configuración (el toggle del editor).
class FlowDetailUpdateSettingsRequested extends FlowDetailEvent {
  const FlowDetailUpdateSettingsRequested({
    required this.aiInvocable,
    required this.cooldownMs,
    required this.usageLimit,
    required this.excludesFlows,
  });

  final bool aiInvocable;
  final int cooldownMs;
  final int usageLimit;
  final List<String> excludesFlows;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowDetailUpdateSettingsRequested) return false;
    if (other.aiInvocable != aiInvocable ||
        other.cooldownMs != cooldownMs ||
        other.usageLimit != usageLimit) {
      return false;
    }
    if (other.excludesFlows.length != excludesFlows.length) return false;
    for (var i = 0; i < excludesFlows.length; i++) {
      if (other.excludesFlows[i] != excludesFlows[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    aiInvocable,
    cooldownMs,
    usageLimit,
    Object.hashAll(excludesFlows),
  );
}
