import '../../domain/entities/template.dart';
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
}
