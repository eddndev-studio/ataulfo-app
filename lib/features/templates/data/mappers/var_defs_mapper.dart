import '../../domain/entities/variable_def.dart';
import '../dto/var_def_dto.dart';

/// Traduce DTOs del listado de variable-definitions a entidades de dominio.
/// El ArgumentError del `VarType.fromWire` se propaga sin envolver — el
/// drift de contrato (un tipo nuevo en el backend que el cliente no
/// conoce) rompe en boot en vez de degradar a un failure reintentable.
class VarDefsMapper {
  const VarDefsMapper._();

  static VariableDef varDefRespToEntity(VarDefResp resp) => VariableDef(
    id: resp.id,
    name: resp.name,
    type: VarType.fromWire(resp.type),
    defaultValue: resp.defaultValue,
    description: resp.description,
  );

  /// Aplana el wrapper {version, defs[]} a la lista de entidades. El
  /// `version` del response NO se expone hoy — sólo lo necesitará el CRUD
  /// (optimistic concurrency en PATCH/DELETE) cuando aterrice. Hasta
  /// entonces, mantenerlo fuera del dominio evita ruido en el consumer.
  static List<VariableDef> listToEntities(ListVarDefsResp resp) =>
      resp.defs.map(varDefRespToEntity).toList(growable: false);
}
