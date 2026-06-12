import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/repositories/media_opener.dart';

/// [MediaOpener] sobre Dio + caché temporal + open_filex: descarga la URL
/// firmada (pública por firma — sin Authorization) a un archivo en la caché
/// de la app y lo entrega al selector "abrir con" del sistema.
///
/// La extensión importa: el sistema elige la app por ella. Se toma del path
/// de la URL si la trae; si no, se deriva del Content-Type de la respuesta.
class DioMediaOpener implements MediaOpener {
  DioMediaOpener({
    Dio? dio,
    Future<Directory> Function()? cacheDir,
    Future<bool> Function(String path)? openFile,
  }) : _dio = dio ?? Dio(),
       _cacheDir = cacheDir ?? getTemporaryDirectory,
       _openFile = openFile ?? _openWithSystem;

  final Dio _dio;
  final Future<Directory> Function() _cacheDir;

  /// Abre el archivo con el sistema; `false` si ninguna app pudo.
  final Future<bool> Function(String path) _openFile;

  static Future<bool> _openWithSystem(String path) async {
    final result = await OpenFilex.open(path);
    return result.type == ResultType.done;
  }

  /// Content-Type → extensión para cuando el path de la URL no trae una.
  /// Cubre lo que WhatsApp transporta hoy; lo no mapeado cae a `bin` (el
  /// selector del sistema aún puede ofrecer apps genéricas).
  static const Map<String, String> _extByType = <String, String>{
    'application/pdf': 'pdf',
    'application/zip': 'zip',
    'application/msword': 'doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        'docx',
    'application/vnd.ms-excel': 'xls',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
    'application/vnd.ms-powerpoint': 'ppt',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        'pptx',
    'text/plain': 'txt',
    'video/mp4': 'mp4',
    'video/3gpp': '3gp',
    'audio/ogg': 'ogg',
    'audio/mpeg': 'mp3',
    'audio/mp4': 'm4a',
    'audio/amr': 'amr',
    'audio/wav': 'wav',
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  @override
  Future<void> open({required String url}) async {
    final Response<List<int>> resp;
    try {
      resp = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
    } on DioException catch (e) {
      throw MediaOpenException('descarga fallida: ${e.message}');
    }
    final bytes = resp.data;
    if (bytes == null || bytes.isEmpty) {
      throw const MediaOpenException('descarga vacía');
    }

    final file = File(await _targetPath(url, resp));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);

    if (!await _openFile(file.path)) {
      throw const MediaOpenException('ninguna app pudo abrir el archivo');
    }
  }

  /// Ruta destino en la caché: el último segmento del path de la URL
  /// (saneado, sin query). Sin extensión ahí, se añade la del Content-Type.
  Future<String> _targetPath(String url, Response<List<int>> resp) async {
    final segments = Uri.parse(url).pathSegments;
    var name = segments.isNotEmpty ? segments.last : 'archivo';
    name = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (name.isEmpty) name = 'archivo';
    if (!name.contains('.')) {
      final contentType =
          resp.headers.value(Headers.contentTypeHeader)?.split(';').first ?? '';
      name = '$name.${_extByType[contentType] ?? 'bin'}';
    }
    final dir = await _cacheDir();
    return '${dir.path}${Platform.pathSeparator}ataulfo_media'
        '${Platform.pathSeparator}$name';
  }
}
