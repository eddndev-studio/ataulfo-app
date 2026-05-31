import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Descarga los bytes de una `previewUrl` firmada (URL absoluta, efímera) para
/// el cache de miniaturas. Usa un [Dio] PROPIO sin interceptores ni baseUrl: la
/// URL ya va firmada, no lleva Bearer y no es relativa al API, así que el
/// cliente principal (JSON + auth) no aplica aquí.
///
/// Passthrough fino sobre la red (untested-by-design): toda la disciplina de
/// cache/decisión vive en `CachingMediaThumbnailLoader`, que se testea con un
/// `download` fake. Devuelve `null` ante cualquier fallo de red/HTTP — el loader
/// lo trata como miss y cae a un placeholder, nunca a un crash.
class DioThumbnailDownloader {
  DioThumbnailDownloader([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<Uint8List?> call(String url) async {
    try {
      final resp = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = resp.data;
      return data == null ? null : Uint8List.fromList(data);
    } on DioException {
      return null;
    }
  }
}
