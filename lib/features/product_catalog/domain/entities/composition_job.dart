/// Estado de un job de composición de fondo. Set cerrado del backend; el
/// wire viaja en mayúsculas (`QUEUED`/`RUNNING`/`DONE`/`FAILED`) y el mapper
/// hace la conversión.
enum CompositionStatus { queued, running, done, failed }

/// Job de composición de fondo de un producto: la IA re-ambienta la foto
/// original sobre un preset de escena. El resultado NO sustituye la foto del
/// producto hasta que el operador lo acepta explícitamente.
///
/// [resultMediaRef] es el ref BARE del resultado en la galería ('' mientras
/// no haya terminado). [errorNote] explica un FAILED ('' en el resto).
/// [model] es el modelo del wire ('' = calidad estándar del plan).
class CompositionJob {
  const CompositionJob({
    required this.id,
    required this.preset,
    required this.model,
    required this.status,
    required this.resultMediaRef,
    required this.errorNote,
    required this.createdAt,
  });

  final String id;

  /// Id del preset de escena (`estudio-blanco`, `marmol`, …). Valor de wire;
  /// el rótulo humano vive en presentación.
  final String preset;

  final String model;
  final CompositionStatus status;
  final String resultMediaRef;
  final String errorNote;
  final DateTime createdAt;

  /// El backend sigue trabajando: la UI lo espera con poll.
  bool get isActive =>
      status == CompositionStatus.queued || status == CompositionStatus.running;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompositionJob &&
        other.id == id &&
        other.preset == preset &&
        other.model == model &&
        other.status == status &&
        other.resultMediaRef == resultMediaRef &&
        other.errorNote == errorNote &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    preset,
    model,
    status,
    resultMediaRef,
    errorNote,
    createdAt,
  );
}
