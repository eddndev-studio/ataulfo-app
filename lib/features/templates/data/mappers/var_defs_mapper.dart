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

  /// Traduce el wrapper {version, defs[]} a una tupla `(version, defs)`.
  /// La version vigente del Template padre la necesita el editor para
  /// mandar el CAS optimista en POST/PATCH/DELETE de var-defs; el wire
  /// no la devuelve en las mutaciones, así que cada refresh del listado
  /// la propaga junto al snapshot de defs.
  static ({int version, List<VariableDef> defs}) listToLoaded(
    ListVarDefsResp resp,
  ) => (
    version: resp.version,
    defs: resp.defs.map(varDefRespToEntity).toList(growable: false),
  );
}
