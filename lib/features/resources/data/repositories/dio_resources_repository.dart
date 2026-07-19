import 'package:dio/dio.dart';

import '../../domain/entities/resource_item.dart';
import '../../domain/repositories/resources_repository.dart';

class DioResourcesRepository implements ResourcesRepository {
  DioResourcesRepository(this._dio);

  final Dio _dio;

  @override
  Future<ResourceSnapshot> listOrganization() async {
    try {
      final response = await _dio.get<Object?>('/resources?active=true');
      return _snapshot(response.data, includePolicy: false);
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<ResourceSnapshot> listForAssistant(String assistantId) async {
    try {
      final id = Uri.encodeComponent(assistantId);
      final response = await _dio.get<Object?>(
        '/assistants/$id/resources?active=true',
      );
      return _snapshot(response.data, includePolicy: true);
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> setScope(
    String assistantId,
    AssistantResourceScope scope,
  ) async {
    try {
      final id = Uri.encodeComponent(assistantId);
      await _dio.put<void>(
        '/assistants/$id/resource-policy',
        data: <String, Object?>{'scopeMode': scope.wire},
      );
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> attach(String assistantId, String resourceId) async {
    try {
      await _dio.put<void>(
        '/assistants/${Uri.encodeComponent(assistantId)}/resources/'
        '${Uri.encodeComponent(resourceId)}',
      );
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> detach(String assistantId, String resourceId) async {
    try {
      await _dio.delete<void>(
        '/assistants/${Uri.encodeComponent(assistantId)}/resources/'
        '${Uri.encodeComponent(resourceId)}',
      );
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  ResourceSnapshot _snapshot(Object? raw, {required bool includePolicy}) {
    final body = _map(raw, 'respuesta de Biblioteca');
    final revision = body['revision'];
    final rows = body['resources'];
    if (revision is! num || rows is! List<Object?>) {
      throw const ResourcesFailure('La Biblioteca devolvió datos incompletos.');
    }
    final resources = <ResourceItem>[];
    for (final row in rows) {
      final json = _map(row, 'recurso');
      final id = json['id'];
      final sourceId = json['sourceId'];
      final kind = json['kind'];
      final name = json['name'];
      final version = json['version'];
      if (id is! String ||
          sourceId is! String ||
          kind is! String ||
          name is! String ||
          version is! num) {
        throw const ResourcesFailure(
          'La Biblioteca contiene un recurso inválido.',
        );
      }
      resources.add(
        ResourceItem(
          id: id,
          sourceId: sourceId,
          kind: ResourceKind.fromWire(kind),
          name: name,
          active: json['active'] == true,
          sharedByDefault: json['sharedByDefault'] == true,
          indexable: json['indexable'] == true,
          sendable: json['sendable'] == true,
          version: version.toInt(),
        ),
      );
    }
    AssistantResourceScope? scope;
    if (includePolicy) {
      final policy = _map(body['policy'], 'política de recursos');
      final mode = policy['scopeMode'];
      if (mode is! String) {
        throw const ResourcesFailure('La política de recursos es inválida.');
      }
      scope = AssistantResourceScope.fromWire(mode);
    }
    return ResourceSnapshot(
      revision: revision.toInt(),
      resources: resources,
      scope: scope,
    );
  }

  Map<String, Object?> _map(Object? value, String label) {
    if (value is Map<String, Object?>) return value;
    if (value is Map<Object?, Object?>) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    throw ResourcesFailure('$label inválida.');
  }

  ResourcesFailure _failure(DioException error) {
    final data = error.response?.data;
    final body = data is Map<Object?, Object?> ? _map(data, 'error') : null;
    if (error.response?.statusCode == 409 &&
        body?['error'] == 'resource_inherited') {
      return const ResourcesFailure(
        'Este recurso está incluido por la organización y no puede quitarse individualmente.',
        inherited: true,
      );
    }
    return switch (error.response?.statusCode) {
      403 => const ResourcesFailure(
        'Tu rol no permite cambiar estos recursos.',
      ),
      404 => const ResourcesFailure('El Asistente o el recurso ya no existe.'),
      _ => const ResourcesFailure('No pudimos actualizar la Biblioteca.'),
    };
  }
}
