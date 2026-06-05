import 'dart:typed_data';

import '../../domain/entities/media_asset.dart';
import '../../domain/repositories/media_repository.dart';
import '../datasources/media_datasource.dart';

/// Implementación fina del puerto: delega en el datasource. Sin cache local en
/// esta capa: el memoizado de la primera página vive en
/// [CachingMediaRepository], que decora a ésta. Por eso aquí [invalidate] es un
/// no-op honesto (no hay nada local que descartar).
class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl({required MediaDatasource datasource}) : _ds = datasource;

  final MediaDatasource _ds;

  @override
  Future<UploadedMedia> upload({
    required Uint8List bytes,
    required String filename,
  }) => _ds.upload(bytes: bytes, filename: filename);

  @override
  Future<MediaPage> listAssets({String? cursor, int? limit, String? type}) =>
      _ds.listAssets(cursor: cursor, limit: limit, type: type);

  @override
  Future<void> delete(String ref) => _ds.delete(ref);

  @override
  void invalidate() {
    // Sin estado local: nada que descartar.
  }
}
