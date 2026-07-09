import '../entities/sticker_job.dart';

/// Repositorio de los stickers de la org. Lanza `StickerFailure` tipadas (el
/// datasource ya tradujo el wire).
abstract interface class StickerRepository {
  Future<List<StickerJob>> list();
  Future<String> generate(String motif);
}
