import '../../domain/entities/template.dart';
import '../../domain/entities/variable_def.dart';
import '../../domain/repositories/templates_repository.dart';
import '../datasources/templates_datasource.dart';

/// Implementación trivial del puerto: el listado no requiere cache local
/// en esta capa (la primera versión refresca contra el backend en cada
/// open). Cuando aterrice RFC-0001 (cache + sync), esta clase orquestará
/// la verdad local vs. remota; hoy es delegate.
class TemplatesRepositoryImpl implements TemplatesRepository {
  TemplatesRepositoryImpl({required TemplatesDatasource datasource})
    : _ds = datasource;

  final TemplatesDatasource _ds;

  @override
  Future<List<Template>> list() => _ds.list();

  @override
  Future<Template> byId(String id) => _ds.byId(id);

  @override
  Future<Template> create(String name) => _ds.create(name);

  @override
  Future<({int version, List<VariableDef> defs})> listVarDefs(String id) =>
      _ds.listVarDefs(id);

  @override
  Future<Template> update({
    required String id,
    required String name,
    required int version,
    required AIConfig? ai,
  }) => _ds.update(id: id, name: name, version: version, ai: ai);

  @override
  Future<VariableDef> addVarDef({
    required String templateId,
    required String name,
    required VarType type,
    required String defaultValue,
    required String description,
    required int version,
  }) => _ds.addVarDef(
    templateId: templateId,
    name: name,
    type: type,
    defaultValue: defaultValue,
    description: description,
    version: version,
  );

  @override
  Future<void> updateVarDef({
    required String varDefId,
    required int version,
    String? name,
    String? defaultValue,
    String? description,
  }) => _ds.updateVarDef(
    varDefId: varDefId,
    version: version,
    name: name,
    defaultValue: defaultValue,
    description: description,
  );

  @override
  Future<void> removeVarDef({
    required String varDefId,
    required int version,
  }) => _ds.removeVarDef(varDefId: varDefId, version: version);
}
