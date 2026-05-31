import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/entities/media_asset.dart';
import '../../domain/repositories/media_page_store.dart';
import 'media_page_json.dart';

/// [MediaPageStore] respaldado por archivos JSON bajo el cache dir de la app
/// (uno por `(orgId, type)`). Cross-platform vía `path_provider`.
///
/// El nombre de archivo es `base64url(orgId\u0000type)`: el separador NUL (que
/// no aparece en un orgId ni en una familia) hace la clave inyectiva, y la
/// codificación la aplana a un segmento filesystem-safe. `type == null` (galería
/// completa) mapea a un token vacío, distinto de cualquier familia concreta.
///
/// [directoryProvider] se inyecta en tests; en producción cae al cache dir.
class FileMediaPageStore implements MediaPageStore {
  FileMediaPageStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationCacheDirectory;

  final Future<Directory> Function() _directoryProvider;

  static const _subdir = 'media_pages';
  static int _writeSeq = 0;

  Future<Directory> _dir() async {
    final base = await _directoryProvider();
    final dir = Directory('${base.path}/$_subdir');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  File _fileFor(Directory dir, String orgId, String? type) {
    final key = '$orgId\u0000${type ?? ''}';
    final name = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    return File('${dir.path}/$name.json');
  }

  @override
  Future<MediaPage?> read(String orgId, String? type) async {
    final file = _fileFor(await _dir(), orgId, type);
    if (!file.existsSync()) return null;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return mediaPageFromJson(json);
    } catch (_) {
      // Archivo corrupto/incompleto: tratar como miss en vez de propagar.
      return null;
    }
  }

  @override
  Future<void> write(String orgId, String? type, MediaPage page) async {
    final file = _fileFor(await _dir(), orgId, type);
    // Escritura atómica (temp + rename): un read concurrente o un crash a media
    // escritura nunca ve un JSON truncado (que el read trataría como corrupto).
    final tmp = File('${file.path}.${_writeSeq++}.tmp');
    try {
      await tmp.writeAsString(jsonEncode(mediaPageToJson(page)), flush: true);
      await tmp.rename(file.path);
    } catch (_) {
      if (tmp.existsSync()) await tmp.delete();
      rethrow;
    }
  }

  @override
  Future<void> clear() async {
    final base = await _directoryProvider();
    final dir = Directory('${base.path}/$_subdir');
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
