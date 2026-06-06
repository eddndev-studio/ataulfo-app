import 'package:dio/dio.dart';

import '../../domain/entities/quick_reply.dart';
import '../../domain/failures/quick_replies_failure.dart';
import '../dto/quick_reply_dto.dart';
import 'quick_replies_errors.dart';

/// Puerto de datos del catálogo de respuestas rápidas WhatsApp (S23): lectura del
/// espejo per-bot. Lanza `QuickRepliesFailure` tipadas; nunca `DioException`
/// cruda. El AuthInterceptor inyecta el Bearer; un drift de contrato (body
/// malformado) degrada a `QuickRepliesUnknownFailure`.
abstract interface class QuickRepliesCatalogDatasource {
  /// `GET /bots/{botId}/quick-replies`. Incluye tombstones (`deleted:true`): el
  /// espejo es fiel; el cliente decide ocultarlos. Lista vacía es válida.
  Future<List<QuickReply>> listCatalog(String botId);
}

class DioQuickRepliesCatalogDatasource
    implements QuickRepliesCatalogDatasource {
  DioQuickRepliesCatalogDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<QuickReply>> listCatalog(String botId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/bots/$botId/quick-replies',
      );
      final body = res.data;
      if (body == null) {
        throw const QuickRepliesUnknownFailure();
      }
      return QuickRepliesCatalogResp.fromJson(body).toEntities();
    } on QuickRepliesFailure {
      rethrow;
    } on DioException catch (e) {
      throw QuickRepliesErrors.read(e);
    } on FormatException {
      throw const QuickRepliesUnknownFailure();
    } on TypeError {
      throw const QuickRepliesUnknownFailure();
    }
  }
}
