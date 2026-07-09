import '../../domain/entities/sticker_job.dart';
import '../dto/sticker_job_dto.dart';

/// Convierte el DTO del wire a la entidad: parsea el `status` del set cerrado
/// (`QUEUED`/`RUNNING`/`DONE`/`FAILED`) y el instante RFC3339 a `DateTime` UTC.
/// Un status fuera del set o una fecha malformada son wire roto
/// (`FormatException`), no casos a tolerar.
class StickerMapper {
  const StickerMapper._();

  static StickerJob dtoToEntity(StickerJobDto dto) => StickerJob(
    id: dto.id,
    motif: dto.motif,
    status: statusFromWire(dto.status),
    resultMediaRef: dto.resultMediaRef,
    errorNote: dto.errorNote,
    createdAt: DateTime.parse(dto.createdAt).toUtc(),
  );

  static StickerStatus statusFromWire(String wire) => switch (wire) {
    'QUEUED' => StickerStatus.queued,
    'RUNNING' => StickerStatus.running,
    'DONE' => StickerStatus.done,
    'FAILED' => StickerStatus.failed,
    _ => throw FormatException('status de sticker desconocido: $wire'),
  };
}
