import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../domain/entities/media_asset.dart';
import '../../domain/failures/media_failure.dart';
import '../dto/media_dto.dart';
import '../mappers/media_mapper.dart';

/// Puerto de datos del catálogo de media.
///
/// Las implementaciones lanzan `MediaFailure` tipadas; nunca DioException
/// cruda. El Bearer lo inyecta el AuthInterceptor del Dio principal (y maneja
/// el refresh en 401): este datasource recibe un Dio ya configurado y sólo
/// llama endpoints.
abstract interface class MediaDatasource {
  /// `POST /upload` multipart: un único part `file`. Devuelve el resultado
  /// mínimo `{ref, previewUrl?}` (201). El backend NO devuelve metadata; se
  /// obtiene re-listando.
  Future<UploadedMedia> upload({
    required Uint8List bytes,
    required String filename,
  });

  /// `GET /media-assets?cursor=&limit=&type=` paginado. Devuelve una página
  /// (assets + nextCursor opaco). [type] filtra por familia del content-type
  /// (image|video|audio|document); null ⇒ sin filtro (todo el catálogo).
  Future<MediaPage> listAssets({String? cursor, int? limit, String? type});

  /// `DELETE /upload/<ref>` (204). Da de baja el asset por su [ref] BARE (que
  /// viaja en el path). El backend borra el objeto y la fila del catálogo. El
  /// 404 (ref inexistente/ajeno) y el 403 (cross-tenant) se mapean a fallos
  /// tipados.
  Future<void> delete(String ref);
}

class DioMediaDatasource implements MediaDatasource {
  DioMediaDatasource(this._dio);

  final Dio _dio;

  @override
  Future<UploadedMedia> upload({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      // El part se nombra `file` (lo que el backend espera). Dio fija el
      // Content-Type multipart con boundary al detectar el FormData, anulando
      // el `application/json` por defecto del cliente.
      final form = FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final res = await _dio.post<Map<String, dynamic>>('/upload', data: form);
      final body = res.data;
      if (body == null) {
        throw const UnknownMediaFailure();
      }
      return MediaMapper.uploadRespToEntity(UploadResp.fromJson(body));
    } on MediaFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownMediaFailure();
    } on TypeError {
      throw const UnknownMediaFailure();
    }
  }

  @override
  Future<MediaPage> listAssets({
    String? cursor,
    int? limit,
    String? type,
  }) async {
    try {
      // Omitimos cada clave cuando el valor es null (null-aware element): el
      // backend distingue "sin cursor" (primera página) de un cursor vacío, y
      // "sin type" (todo el catálogo) de una familia concreta.
      final query = <String, dynamic>{
        'cursor': ?cursor,
        'limit': ?limit,
        'type': ?type,
      };
      final res = await _dio.get<Map<String, dynamic>>(
        '/media-assets',
        queryParameters: query,
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownMediaFailure();
      }
      return MediaMapper.listRespToPage(MediaListResp.fromJson(body));
    } on MediaFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownMediaFailure();
    } on TypeError {
      // `cast<Map<String,dynamic>>` rompe si el wire mete un tipo inesperado.
      throw const UnknownMediaFailure();
    }
  }

  @override
  Future<void> delete(String ref) async {
    try {
      // El ref BARE (tenant/<org>/media/<id>[.<ext>]) va en el path; el backend
      // valida tenant y da de baja objeto + fila de catálogo (204).
      await _dio.delete<void>('/upload/$ref');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Traduce DioException a la jerarquía sellada. 413/415 son específicos de la
  /// subida; 401 final (refresh agotado) y 400 (form/cursor inválido) colapsan
  /// a Unknown — el AuthInterceptor ya intentó el refresh.
  MediaFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const MediaTimeoutFailure();
      case DioExceptionType.connectionError:
        return const MediaNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const MediaForbiddenFailure();
        if (status == 404) return const MediaNotFoundFailure();
        if (status == 413) return const MediaTooLargeFailure();
        if (status == 415) return const MediaUnsupportedTypeFailure();
        if (status >= 500 && status < 600) return const MediaServerFailure();
        return const UnknownMediaFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownMediaFailure();
    }
  }
}
