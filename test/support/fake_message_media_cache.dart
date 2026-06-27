import 'dart:typed_data';

import 'package:ataulfo/features/media/domain/repositories/media_byte_store.dart';
import 'package:ataulfo/features/messages/data/cache/message_media_cache.dart';

class _MemByteStore implements MediaByteStore {
  final Map<String, Uint8List> _m = <String, Uint8List>{};

  @override
  Future<Uint8List?> read(String ref) async => _m[ref];

  @override
  Future<void> write(String ref, Uint8List bytes) async {
    _m[ref] = bytes;
  }
}

/// [MessageMediaCache] para tests: store en memoria + descarga configurable
/// ([downloadResult], por defecto `null` = no hay bytes / offline).
MessageMediaCache fakeMessageMediaCache({Uint8List? downloadResult}) =>
    MessageMediaCache(
      store: _MemByteStore(),
      download: (_) async => downloadResult,
    );
