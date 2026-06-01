import 'package:dio/dio.dart';

import '../../domain/entities/wa_label.dart';
import '../../domain/failures/wa_labels_failure.dart';
import '../dto/wa_label_dto.dart';
import '../mappers/wa_labels_mapper.dart';
import 'wa_labels_errors.dart';

/// Puerto de datos del catálogo de etiquetas WhatsApp (S21): lectura del
/// espejo + CRUD que empuja al cliente WhatsApp (el espejo se reconcilia por el
/// evento eco entrante, no por la respuesta de la mutación).
///
/// Lanza `WaLabelsFailure` tipadas; nunca `DioException` cruda. El
/// AuthInterceptor inyecta el Bearer; un drift de contrato (body malformado)
/// degrada a `WaLabelsUnknownFailure`.
abstract interface class WaCatalogDatasource {
  /// `GET /bots/{botId}/wa-labels`. Incluye tombstones (`deleted:true`): el
  /// espejo es fiel; el cliente decide ocultarlos. Lista vacía es válida.
  Future<List<WaLabel>> listCatalog(String botId);

  /// `POST /bots/{botId}/wa-labels` body `{name, color}`. El servidor asigna el
  /// `waLabelId` (>=1000) y empuja la creación a WhatsApp; responde 201 con la
  /// etiqueta. 422 nombre vacío; 409 bot no conectado; 502 fallo upstream WA.
  Future<WaLabel> createLabel({
    required String botId,
    required String name,
    required int color,
  });

  /// `PUT /bots/{botId}/wa-labels/{waLabelId}` body `{name, color}`. Empuja la
  /// edición (mismo id). Mismos failures de push que create.
  Future<WaLabel> updateLabel({
    required String botId,
    required String waLabelId,
    required String name,
    required int color,
  });

  /// `DELETE /bots/{botId}/wa-labels/{waLabelId}`. Empuja el borrado (tombstone)
  /// y responde 200 sin body. 404 aquí = bot ajeno/inexistente (NO idempotente:
  /// la única fuente de 404 es el guard de propiedad del bot).
  Future<void> deleteLabel({required String botId, required String waLabelId});
}

class DioWaCatalogDatasource implements WaCatalogDatasource {
  DioWaCatalogDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<WaLabel>> listCatalog(String botId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/bots/$botId/wa-labels');
      final body = res.data;
      if (body == null) {
        throw const WaLabelsUnknownFailure();
      }
      return WaLabelsMapper.catalogToLabels(WaCatalogResp.fromJson(body));
    } on WaLabelsFailure {
      rethrow;
    } on DioException catch (e) {
      throw WaLabelsErrors.read(e);
    } on FormatException {
      throw const WaLabelsUnknownFailure();
    } on TypeError {
      throw const WaLabelsUnknownFailure();
    }
  }

  @override
  Future<WaLabel> createLabel({
    required String botId,
    required String name,
    required int color,
  }) => _edit(
    () => _dio.post<Map<String, dynamic>>(
      '/bots/$botId/wa-labels',
      data: <String, dynamic>{'name': name, 'color': color},
    ),
  );

  @override
  Future<WaLabel> updateLabel({
    required String botId,
    required String waLabelId,
    required String name,
    required int color,
  }) => _edit(
    () => _dio.put<Map<String, dynamic>>(
      '/bots/$botId/wa-labels/$waLabelId',
      data: <String, dynamic>{'name': name, 'color': color},
    ),
  );

  @override
  Future<void> deleteLabel({
    required String botId,
    required String waLabelId,
  }) async {
    try {
      await _dio.delete<void>('/bots/$botId/wa-labels/$waLabelId');
    } on DioException catch (e) {
      throw WaLabelsErrors.push(e);
    }
  }

  /// Cuerpo común de create/update: ambos POST/PUT devuelven la etiqueta y
  /// mapean errores de push (422/409/502). Aísla la repetición del try/catch.
  Future<WaLabel> _edit(
    Future<Response<Map<String, dynamic>>> Function() send,
  ) async {
    try {
      final res = await send();
      final body = res.data;
      if (body == null) {
        throw const WaLabelsUnknownFailure();
      }
      return WaLabelsMapper.labelToEntity(WaLabelResp.fromJson(body));
    } on WaLabelsFailure {
      rethrow;
    } on DioException catch (e) {
      throw WaLabelsErrors.push(e);
    } on FormatException {
      throw const WaLabelsUnknownFailure();
    } on TypeError {
      throw const WaLabelsUnknownFailure();
    }
  }
}
