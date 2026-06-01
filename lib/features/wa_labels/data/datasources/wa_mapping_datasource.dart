import 'package:dio/dio.dart';

import '../../domain/entities/wa_label_mapping.dart';
import '../../domain/failures/wa_labels_failure.dart';
import '../dto/wa_mapping_dto.dart';
import '../mappers/wa_labels_mapper.dart';
import 'wa_labels_errors.dart';

/// Puerto de datos del mapeo explícito etiqueta-WhatsApp ↔ Label interno (S21,
/// Dirección 2). NO empuja a WhatsApp (invariante I-L1a): es metadata interna,
/// así que sus mutaciones nunca producen failures de push (409/502) — solo
/// 422 (label inexistente/fuera de org) además de los failures comunes.
abstract interface class WaMappingDatasource {
  /// `GET /bots/{botId}/wa-label-mappings`. Mapeos del bot.
  Future<List<WaLabelMapping>> listMappings(String botId);

  /// `PUT /bots/{botId}/wa-labels/{waLabelId}/mapping` body `{labelId}`. Fija o
  /// re-mapea (upsert). 422 si el `labelId` está vacío o no existe en la org
  /// del bot.
  Future<WaLabelMapping> setMapping({
    required String botId,
    required String waLabelId,
    required String labelId,
  });

  /// `DELETE /bots/{botId}/wa-labels/{waLabelId}/mapping`. Quita el vínculo
  /// (idempotente; 200 sin body). 404 = bot ajeno/inexistente.
  Future<void> deleteMapping({
    required String botId,
    required String waLabelId,
  });
}

class DioWaMappingDatasource implements WaMappingDatasource {
  DioWaMappingDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<WaLabelMapping>> listMappings(String botId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/bots/$botId/wa-label-mappings',
      );
      final body = res.data;
      if (body == null) {
        throw const WaLabelsUnknownFailure();
      }
      return WaLabelsMapper.mappingsToEntities(WaMappingListResp.fromJson(body));
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
  Future<WaLabelMapping> setMapping({
    required String botId,
    required String waLabelId,
    required String labelId,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/bots/$botId/wa-labels/$waLabelId/mapping',
        data: <String, dynamic>{'labelId': labelId},
      );
      final body = res.data;
      if (body == null) {
        throw const WaLabelsUnknownFailure();
      }
      return WaLabelsMapper.mappingToEntity(WaMappingResp.fromJson(body));
    } on WaLabelsFailure {
      rethrow;
    } on DioException catch (e) {
      throw WaLabelsErrors.mapping(e);
    } on FormatException {
      throw const WaLabelsUnknownFailure();
    } on TypeError {
      throw const WaLabelsUnknownFailure();
    }
  }

  @override
  Future<void> deleteMapping({
    required String botId,
    required String waLabelId,
  }) async {
    try {
      await _dio.delete<void>('/bots/$botId/wa-labels/$waLabelId/mapping');
    } on DioException catch (e) {
      throw WaLabelsErrors.read(e);
    }
  }
}
