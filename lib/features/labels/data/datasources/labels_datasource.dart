import 'package:dio/dio.dart';

import '../../domain/entities/label.dart';
import '../../domain/failures/labels_failure.dart';
import '../dto/label_dto.dart';
import '../mappers/labels_mapper.dart';

/// Puerto de datos del catálogo de Labels internos (S10), org-scoped. Lectura
/// (`GET /labels`) y mutaciones (`POST`/`PUT`/`DELETE /labels`). Lanza
/// `LabelsFailure` tipadas; el AuthInterceptor inyecta el Bearer.
abstract interface class LabelsDatasource {
  /// `GET /labels`. Lista org-scoped. Vacía es válida. 403 si el rol no alcanza.
  Future<List<Label>> listLabels();

  /// `POST /labels`. Crea una etiqueta org-scoped y devuelve la creada (con su
  /// id). 422 si name/color inválidos, 409 si el nombre ya existe en la org.
  Future<Label> createLabel({
    required String name,
    required String color,
    required String description,
  });

  /// `PUT /labels/{id}`. Reemplaza name/color/description (documento plano) y
  /// devuelve la actualizada. 404 si no existe, 409 si choca con otro nombre,
  /// 422 si inválida.
  Future<Label> updateLabel({
    required String id,
    required String name,
    required String color,
    required String description,
  });

  /// `DELETE /labels/{id}`. Borrado definitivo (el backend cascada sobre las
  /// asignaciones a conversaciones). 404 si no existe.
  Future<void> deleteLabel({required String id});
}

class DioLabelsDatasource implements LabelsDatasource {
  DioLabelsDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<Label>> listLabels() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/labels');
      final body = res.data;
      if (body == null) {
        throw const LabelsUnknownFailure();
      }
      return LabelsMapper.listToLabels(LabelListResp.fromJson(body));
    } on LabelsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const LabelsUnknownFailure();
    } on TypeError {
      throw const LabelsUnknownFailure();
    }
  }

  @override
  Future<Label> createLabel({
    required String name,
    required String color,
    required String description,
  }) => _upsert(
    () => _dio.post<Map<String, dynamic>>(
      '/labels',
      data: LabelUpsertReq(
        name: name,
        color: color,
        description: description,
      ).toJson(),
    ),
  );

  @override
  Future<Label> updateLabel({
    required String id,
    required String name,
    required String color,
    required String description,
  }) => _upsert(
    () => _dio.put<Map<String, dynamic>>(
      '/labels/$id',
      data: LabelUpsertReq(
        name: name,
        color: color,
        description: description,
      ).toJson(),
    ),
  );

  @override
  Future<void> deleteLabel({required String id}) async {
    try {
      await _dio.delete<void>('/labels/$id');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Ejecuta un POST/PUT que devuelve un único Label y lo mapea a dominio.
  /// Centraliza el manejo de errores común a create/update.
  Future<Label> _upsert(
    Future<Response<Map<String, dynamic>>> Function() call,
  ) async {
    try {
      final res = await call();
      final body = res.data;
      if (body == null) {
        throw const LabelsUnknownFailure();
      }
      return LabelsMapper.toEntity(LabelResp.fromJson(body));
    } on LabelsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const LabelsUnknownFailure();
    } on TypeError {
      throw const LabelsUnknownFailure();
    }
  }

  LabelsFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const LabelsTimeoutFailure();
      case DioExceptionType.connectionError:
        return const LabelsNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const LabelsForbiddenFailure();
        if (status == 404) return const LabelsNotFoundFailure();
        if (status == 409) return const LabelsDuplicateNameFailure();
        if (status == 422) return const LabelsValidationFailure();
        if (status >= 500 && status < 600) {
          return const LabelsServerFailure();
        }
        return const LabelsUnknownFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const LabelsUnknownFailure();
    }
  }
}
