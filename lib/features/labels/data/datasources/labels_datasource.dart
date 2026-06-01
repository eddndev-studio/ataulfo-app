import 'package:dio/dio.dart';

import '../../domain/entities/label.dart';
import '../../domain/failures/labels_failure.dart';
import '../dto/label_dto.dart';
import '../mappers/labels_mapper.dart';

/// Puerto de datos de Labels internos (S10). En esta capa solo lectura: el
/// catálogo org-scoped que puebla el selector del mapeo WA↔interno. Lanza
/// `LabelsFailure` tipadas; el AuthInterceptor inyecta el Bearer.
abstract interface class LabelsDatasource {
  /// `GET /labels`. Lista org-scoped. Vacía es válida. 403 si el rol no alcanza.
  Future<List<Label>> listLabels();
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
