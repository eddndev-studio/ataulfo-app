import '../../domain/entities/sticker_job.dart';
import '../../domain/repositories/sticker_repository.dart';
import '../datasources/sticker_datasource.dart';

/// Implementación sobre el datasource HTTP. Passthrough: el datasource ya
/// entrega entidades de dominio y fallas tipadas.
class StickerRepositoryImpl implements StickerRepository {
  const StickerRepositoryImpl({required this.datasource});

  final StickerDatasource datasource;

  @override
  Future<List<StickerJob>> list() => datasource.list();

  @override
  Future<String> generate(String motif) => datasource.generate(motif);
}
