import 'package:dio/dio.dart';

import '../../domain/entities/catalog_appearance.dart';
import '../../domain/entities/public_catalog_settings.dart';
import '../../domain/failures/public_catalog_failure.dart';
import '../dto/public_catalog_settings_dto.dart';

/// Puerto de datos de `/workspace/organization/public-catalog` (ADMIN+). Las
/// impls lanzan `PublicCatalogFailure` tipadas; nunca DioException cruda.
abstract interface class PublicCatalogDatasource {
  Future<PublicCatalogSettings> get();
  Future<PublicCatalogSettings> update({
    required bool enabled,
    required String slug,
    required CatalogDesign design,
    required CatalogAccent accent,
  });
}

class DioPublicCatalogDatasource implements PublicCatalogDatasource {
  DioPublicCatalogDatasource(this._dio);

  final Dio _dio;

  static const String _path = '/workspace/organization/public-catalog';

  @override
  Future<PublicCatalogSettings> get() => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(_path);
    final body = res.data;
    if (body == null) throw const FormatException('body nulo');
    return PublicCatalogSettingsDto.fromJson(body).toEntity();
  });

  @override
  Future<PublicCatalogSettings> update({
    required bool enabled,
    required String slug,
    required CatalogDesign design,
    required CatalogAccent accent,
  }) => _guard(() async {
    final res = await _dio.put<Map<String, dynamic>>(
      _path,
      // Slug vacío se OMITE: el backend conserva el persistido o genera uno al
      // activar. Un slug propuesto sólo viaja cuando el operador lo escribió.
      // design/accent SIEMPRE viajan (el valor vigente): el backend conserva lo
      // que no se manda, así que omitirlos impediría cambiarlos.
      data: <String, dynamic>{
        'enabled': enabled,
        if (slug.isNotEmpty) 'slug': slug,
        'design': design.wire,
        'accent': accent.wire,
      },
    );
    final body = res.data;
    if (body == null) throw const FormatException('body nulo');
    return PublicCatalogSettingsDto.fromJson(body).toEntity();
  });

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on PublicCatalogFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const PublicCatalogUnknownFailure();
    } on TypeError {
      throw const PublicCatalogUnknownFailure();
    }
  }

  PublicCatalogFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const PublicCatalogNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        final code = _code(e.response?.data);
        if (status == 403) return const PublicCatalogForbiddenFailure();
        if (status == 409 && code == 'slug_taken') {
          return const PublicCatalogSlugTakenFailure();
        }
        // 422 llega por el slug (forma/reservado) o por la apariencia
        // (invalid_design/invalid_accent): el code los separa para que la vista
        // señale el campo correcto. Un 422 sin code conocido degrada a Unknown.
        if (status == 422) {
          return switch (code) {
            'invalid_slug' => const PublicCatalogInvalidSlugFailure(),
            'invalid_design' ||
            'invalid_accent' => const PublicCatalogInvalidAppearanceFailure(),
            _ => const PublicCatalogUnknownFailure(),
          };
        }
        if (status >= 500 && status < 600) {
          return const PublicCatalogServerFailure();
        }
        return const PublicCatalogUnknownFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const PublicCatalogUnknownFailure();
    }
  }

  /// Código estable del cuerpo `{"error": code}`; ausente o no-string ⇒ null.
  String? _code(dynamic data) {
    if (data is! Map) return null;
    final c = data['error'];
    return c is String ? c : null;
  }
}
