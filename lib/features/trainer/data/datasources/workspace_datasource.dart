import 'package:dio/dio.dart';

import '../../domain/entities/workspace_doc.dart';
import '../../domain/failures/trainer_failure.dart';
import '../dto/workspace_doc_dto.dart';
import 'failure_mapper.dart';

/// Puerto de datos del Workspace de negocio (S24), template-scoped.
/// Lanza `TrainerFailure` tipadas; el AuthInterceptor inyecta el Bearer.
abstract interface class WorkspaceDatasource {
  /// `GET /templates/{id}/workspace/docs` — listado SIN content.
  Future<List<WorkspaceDoc>> listDocs({required String templateId});

  /// `GET .../docs/{name}` — doc completo (con content).
  Future<WorkspaceDoc> getDoc({
    required String templateId,
    required String name,
  });

  /// `POST .../docs` — crea; 409 nombre duplicado, 422 slug/caps.
  Future<WorkspaceDoc> createDoc({
    required String templateId,
    required String name,
    required String content,
  });

  /// `PUT .../docs/{name}` con CAS (`version`). 409 ⇒ recargar.
  Future<WorkspaceDoc> updateDoc({
    required String templateId,
    required String name,
    required String content,
    required int version,
  });

  /// `DELETE .../docs/{name}?version=N`.
  Future<void> deleteDoc({
    required String templateId,
    required String name,
    required int version,
  });
}

class DioWorkspaceDatasource implements WorkspaceDatasource {
  DioWorkspaceDatasource(this._dio);

  final Dio _dio;

  String _base(String templateId) => '/templates/$templateId/workspace/docs';

  @override
  Future<List<WorkspaceDoc>> listDocs({required String templateId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(_base(templateId));
      final body = res.data;
      final docs = body?['docs'];
      if (docs is! List<dynamic>) {
        throw const TrainerUnknownFailure();
      }
      return docs
          .map(
            (e) =>
                WorkspaceDocDto.fromJson(e as Map<String, dynamic>).toEntity(),
          )
          .toList(growable: false);
    } on TrainerFailure {
      rethrow;
    } on DioException catch (e) {
      throw mapTrainerDioException(e);
    } on FormatException {
      throw const TrainerUnknownFailure();
    } on TypeError {
      throw const TrainerUnknownFailure();
    }
  }

  @override
  Future<WorkspaceDoc> getDoc({
    required String templateId,
    required String name,
  }) => _docCall(
    () => _dio.get<Map<String, dynamic>>('${_base(templateId)}/$name'),
  );

  @override
  Future<WorkspaceDoc> createDoc({
    required String templateId,
    required String name,
    required String content,
  }) => _docCall(
    () => _dio.post<Map<String, dynamic>>(
      _base(templateId),
      data: <String, dynamic>{'name': name, 'content': content},
    ),
  );

  @override
  Future<WorkspaceDoc> updateDoc({
    required String templateId,
    required String name,
    required String content,
    required int version,
  }) => _docCall(
    () => _dio.put<Map<String, dynamic>>(
      '${_base(templateId)}/$name',
      data: <String, dynamic>{'content': content, 'version': version},
    ),
  );

  @override
  Future<void> deleteDoc({
    required String templateId,
    required String name,
    required int version,
  }) async {
    try {
      await _dio.delete<void>(
        '${_base(templateId)}/$name',
        // CAS en query (DELETE sin body), convención compartida con notas.
        queryParameters: <String, dynamic>{'version': '$version'},
      );
    } on DioException catch (e) {
      throw mapTrainerDioException(e);
    }
  }

  Future<WorkspaceDoc> _docCall(
    Future<Response<Map<String, dynamic>>> Function() call,
  ) async {
    try {
      final res = await call();
      final body = res.data;
      if (body == null) {
        throw const TrainerUnknownFailure();
      }
      return WorkspaceDocDto.fromJson(body).toEntity();
    } on TrainerFailure {
      rethrow;
    } on DioException catch (e) {
      throw mapTrainerDioException(e);
    } on FormatException {
      throw const TrainerUnknownFailure();
    } on TypeError {
      throw const TrainerUnknownFailure();
    }
  }
}
