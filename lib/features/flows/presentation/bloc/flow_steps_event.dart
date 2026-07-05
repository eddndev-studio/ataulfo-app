// Eventos del FlowStepsBloc. Parte de la librería del bloc: los tipos
// sellados del wire de eventos viven en su archivo hermano para que la
// unidad quede legible sin inflar el archivo del orquestador.
part of 'flow_steps_bloc.dart';

sealed class FlowStepsEvent {
  const FlowStepsEvent();
}

class FlowStepsLoadRequested extends FlowStepsEvent {
  const FlowStepsLoadRequested();
  @override
  bool operator ==(Object other) => other is FlowStepsLoadRequested;
  @override
  int get hashCode => (FlowStepsLoadRequested).hashCode;
}

/// Pide refrescar el listado CONSERVANDO la lista visible (sin pasar por
/// Loading). Es el retry natural tras un RefreshFailed; para el arranque
/// o el retry de un Failed terminal está [FlowStepsLoadRequested].
class FlowStepsRefreshRequested extends FlowStepsEvent {
  const FlowStepsRefreshRequested();
  @override
  bool operator ==(Object other) => other is FlowStepsRefreshRequested;
  @override
  int get hashCode => (FlowStepsRefreshRequested).hashCode;
}

/// Pide agregar un step nuevo al final de la lista. El bloc resuelve el
/// `order` (= longitud del snapshot vigente) — el usuario no decide
/// posición al crear; reorder es una operación distinta.
///
/// `type` y `mediaRef` los elige el sheet: TEXT usa `mediaRef:''`; los
/// tipos multimedia (IMAGE/VIDEO/DOCUMENT/AUDIO/PTT/STICKER) viajan con
/// `mediaRef` no vacío y `content` opcional como caption. Defaults
/// `type:text` + `mediaRef:''` para callers que no necesitan elegir
/// (atajo del path TEXT sin tener que repetir los dos campos).
class FlowStepsAddRequested extends FlowStepsEvent {
  const FlowStepsAddRequested({
    required this.content,
    required this.delayMs,
    required this.jitterPct,
    required this.aiOnly,
    this.manualOnly = false,
    this.type = fdom.StepType.text,
    this.mediaRef = '',
    this.metadataJson,
    this.order,
  });

  final fdom.StepType type;
  final String mediaRef;
  final String content;
  final int delayMs;
  final int jitterPct;
  final bool aiOnly;

  /// Posición de INSERCIÓN explícita (el backend desplaza los steps en y
  /// después de esa posición). Null ⇒ append al final. La usa el
  /// condicional, que debe quedar antes de sus destinos.
  final int? order;

  /// Inverso de [aiOnly]: el paso solo corre por disparador/arranque manual.
  /// El selector del sheet garantiza que nunca viajen ambos en true.
  final bool manualOnly;

  /// Shape literal de `Step.metadata` para el step nuevo. Hoy lo necesita
  /// solo CONDITIONAL_TIME (ventanas); null para los otros tipos —el
  /// backend les pone `{}` por defecto.
  final String? metadataJson;

  @override
  bool operator ==(Object other) =>
      other is FlowStepsAddRequested &&
      other.type == type &&
      other.mediaRef == mediaRef &&
      other.content == content &&
      other.delayMs == delayMs &&
      other.jitterPct == jitterPct &&
      other.aiOnly == aiOnly &&
      other.manualOnly == manualOnly &&
      other.metadataJson == metadataJson &&
      other.order == order;

  @override
  int get hashCode => Object.hash(
    type,
    mediaRef,
    content,
    delayMs,
    jitterPct,
    aiOnly,
    manualOnly,
    metadataJson,
    order,
  );
}

/// Pide editar un step (partial update). Cualquier campo `null` se omite
/// del PATCH — preservar = omitir. La UI computa el diff contra el step
/// original antes de despachar; si nada cambió, no debería despachar el
/// evento. El bloc no re-valida no-op (asume que la UI hizo su trabajo).
class FlowStepsUpdateRequested extends FlowStepsEvent {
  const FlowStepsUpdateRequested({
    required this.stepId,
    this.content,
    this.mediaRef,
    this.delayMs,
    this.jitterPct,
    this.aiOnly,
    this.manualOnly,
    this.metadataJson,
  });

  final String stepId;
  final String? content;

  /// Nuevo `ref` BARE del recurso multimedia cuando el operador lo
  /// reemplaza. Null = preservar el recurso actual (omitido del PATCH).
  /// Siempre el ref BARE canónico — jamás la URL firmada efímera.
  final String? mediaRef;
  final int? delayMs;
  final int? jitterPct;
  final bool? aiOnly;

  /// Cambio del modo "solo disparadores". Null = preservar (omitido).
  final bool? manualOnly;

  /// Nuevo shape de `Step.metadata` para el step. Null = preservar el
  /// metadata actual del backend (omitido del PATCH).
  final String? metadataJson;

  @override
  bool operator ==(Object other) =>
      other is FlowStepsUpdateRequested &&
      other.stepId == stepId &&
      other.content == content &&
      other.mediaRef == mediaRef &&
      other.delayMs == delayMs &&
      other.jitterPct == jitterPct &&
      other.aiOnly == aiOnly &&
      other.manualOnly == manualOnly &&
      other.metadataJson == metadataJson;

  @override
  int get hashCode => Object.hash(
    stepId,
    content,
    mediaRef,
    delayMs,
    jitterPct,
    aiOnly,
    manualOnly,
    metadataJson,
  );
}

/// Pide eliminar un step. La operación es idempotente en el backend,
/// así que el bloc no necesita gates especiales — tras éxito el step
/// desaparece del refetch.
class FlowStepsDeleteRequested extends FlowStepsEvent {
  const FlowStepsDeleteRequested(this.stepId);

  final String stepId;

  @override
  bool operator ==(Object other) =>
      other is FlowStepsDeleteRequested && other.stepId == stepId;

  @override
  int get hashCode => stepId.hashCode;
}

/// Pide reordenar la lista de steps. `ids` es el array completo de
/// ids de step en el orden destino — el bloc compara contra el
/// snapshot vigente y dispara PATCH solo para los que cambiaron de
/// posición (skip de no-ops). La UX típica (`ReorderableListView`)
/// reconstruye este array al soltar el drag.
class FlowStepsReorderRequested extends FlowStepsEvent {
  const FlowStepsReorderRequested(this.ids);

  final List<String> ids;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowStepsReorderRequested) return false;
    if (other.ids.length != ids.length) return false;
    for (var i = 0; i < ids.length; i++) {
      if (other.ids[i] != ids[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(ids);
}
