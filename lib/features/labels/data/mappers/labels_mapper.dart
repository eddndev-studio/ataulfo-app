import '../../domain/entities/label.dart';
import '../dto/label_dto.dart';

/// Traduce DTOs del listado de Labels internos a entidades de dominio,
/// preservando el orden del backend.
class LabelsMapper {
  const LabelsMapper._();

  static Label toEntity(LabelResp r) =>
      Label(id: r.id, name: r.name, color: r.color, description: r.description);

  static List<Label> listToLabels(LabelListResp resp) =>
      resp.items.map(toEntity).toList(growable: false);
}
