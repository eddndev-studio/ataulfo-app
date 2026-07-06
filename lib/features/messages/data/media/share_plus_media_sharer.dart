import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/repositories/media_sharer.dart';

/// [MediaSharer] sobre share_plus: materializa los bytes a un archivo en la
/// caché temporal de la app (el share sheet del sistema comparte ARCHIVOS,
/// no memoria) y lo entrega a `SharePlus.share`. El nombre importa: es el que
/// verá la app receptora, y su extensión decide cómo lo trata.
class SharePlusMediaSharer implements MediaSharer {
  SharePlusMediaSharer({
    Future<Directory> Function()? cacheDir,
    Future<void> Function(String path)? shareFile,
  }) : _cacheDir = cacheDir ?? getTemporaryDirectory,
       _shareFile = shareFile ?? _shareWithSystem;

  final Future<Directory> Function() _cacheDir;

  /// Entrega el archivo al share sheet del sistema (inyectable en tests).
  final Future<void> Function(String path) _shareFile;

  static Future<void> _shareWithSystem(String path) async {
    final result = await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(path)]),
    );
    if (result.status == ShareResultStatus.unavailable) {
      throw const MediaShareException('compartir no disponible');
    }
  }

  @override
  Future<void> share({
    required Uint8List bytes,
    required String filename,
  }) async {
    final safe = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final name = safe.isEmpty ? 'archivo' : safe;
    final File file;
    try {
      final dir = await _cacheDir();
      file = File(
        '${dir.path}${Platform.pathSeparator}ataulfo_share'
        '${Platform.pathSeparator}$name',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      throw MediaShareException('no se pudo materializar: $e');
    }
    await _shareFile(file.path);
  }
}
