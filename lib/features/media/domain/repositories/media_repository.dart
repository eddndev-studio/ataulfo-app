import 'dart:typed_data';

import '../entities/media_asset.dart';

/// Puerto de dominio para el catálogo de media. Define los verbos que el bloc
/// puede pedir; la implementación vive en `data/`. Lanza `MediaFailure` tipadas
/// (no DioException cruda); el bloc traduce a estado de UI.
abstract interface class MediaRepository {
  /// Sube un archivo (`POST /upload`). Devuelve el resultado MÍNIMO
  /// `{ref, previewUrl?}`; la metadata completa (filename/size/createdAt) se
  /// obtiene re-listando. Lanza `MediaTooLargeFailure` (413),
  /// `MediaUnsupportedTypeFailure` (415) y las variantes de red/server.
  Future<UploadedMedia> upload({
    required Uint8List bytes,
    required String filename,
  });

  /// Lista una página del catálogo (`GET /media-assets`). [cursor] vacío/null
  /// pide la primera página; [limit] acota el tamaño; [type] filtra por familia
  /// del content-type (image|video|audio|document), null ⇒ sin filtro.
  /// `MediaPage.nextCursor` vacío ⇒ no hay más páginas.
  Future<MediaPage> listAssets({String? cursor, int? limit, String? type});
}
