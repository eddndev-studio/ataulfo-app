import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'media_byte_store.dart';

/// [MediaByteStore] respaldado por el sistema de archivos (un archivo por ref
/// bajo el cache dir de la app). Cross-platform: usa `path_provider` para el
/// directorio base, así que sirve igual en Android y en escritorio.
///
/// El nombre de archivo es `base64url(ref)` sin padding: el ref trae '/' y '.'
/// (`tenant/org/media/id.png`), que como ruta crearían subdirectorios; la
/// codificación lo aplana a un único segmento filesystem-safe, sin riesgo de
/// path traversal ni colisión entre refs.
///
/// [directoryProvider] permite inyectar un directorio temporal en tests (sin
/// tocar el plugin nativo). En producción cae al cache dir de la app.
class FileMediaByteStore implements MediaByteStore {
  FileMediaByteStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationCacheDirectory;

  final Future<Directory> Function() _directoryProvider;

  static const _subdir = 'media_bytes';

  Future<Directory> _dir() async {
    final base = await _directoryProvider();
    final dir = Directory('${base.path}/$_subdir');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  File _fileFor(Directory dir, String ref) {
    final name = base64Url.encode(utf8.encode(ref)).replaceAll('=', '');
    return File('${dir.path}/$name');
  }

  @override
  Future<Uint8List?> read(String ref) async {
    final file = _fileFor(await _dir(), ref);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> write(String ref, Uint8List bytes) async {
    final file = _fileFor(await _dir(), ref);
    await file.writeAsBytes(bytes, flush: true);
  }
}
