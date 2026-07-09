import '../../domain/entities/composition_job.dart';
import '../dto/composition_job_dto.dart';

/// Convierte el DTO del wire a la entidad de dominio: parsea el `status` del
/// set cerrado (`QUEUED`/`RUNNING`/`DONE`/`FAILED`) y el instante RFC3339 a
/// `DateTime` UTC. Un status fuera del set o una fecha malformada son wire
/// roto (`FormatException`), no casos a tolerar.
class CompositionMapper {
  const CompositionMapper._();

  static CompositionJob dtoToEntity(CompositionJobDto dto) => CompositionJob(
    id: dto.id,
    preset: dto.preset,
    model: dto.model,
    status: statusFromWire(dto.status),
    resultMediaRef: dto.resultMediaRef,
    errorNote: dto.errorNote,
    createdAt: DateTime.parse(dto.createdAt).toUtc(),
  );

  static CompositionStatus statusFromWire(String wire) => switch (wire) {
    'QUEUED' => CompositionStatus.queued,
    'RUNNING' => CompositionStatus.running,
    'DONE' => CompositionStatus.done,
    'FAILED' => CompositionStatus.failed,
    _ => throw FormatException('status de composición desconocido: $wire'),
  };
}
