import '../entities/composition_job.dart';

/// Puerto de la composición de fondos («Mejorar foto con IA»): encolar un
/// job, listar los del producto y aceptar/descartar un resultado. Las
/// implementaciones lanzan `CompositionFailure` tipadas; el dominio no
/// conoce el transporte.
abstract interface class CompositionRepository {
  /// `POST /workspace/catalog/products/{id}/compose` (ADMIN+). Encola la
  /// composición de la foto ACTUAL del producto sobre [preset]; [premium]
  /// pide la calidad Pro/Business. Devuelve el id del job. 422 si el
  /// producto no tiene foto, la cuota se agotó o el plan no alcanza.
  Future<String> compose({
    required String productId,
    required String preset,
    bool premium = false,
  });

  /// `GET /workspace/catalog/products/{id}/compositions` — los jobs del
  /// producto, recientes primero (orden del backend).
  Future<List<CompositionJob>> listJobs(String productId);

  /// `POST /workspace/catalog/compositions/{jobId}/accept` — el resultado
  /// pasa a ser la foto del producto. 409 si el job no ha terminado; 422 si
  /// la imagen ya no está en la galería.
  Future<void> accept(String jobId);

  /// `POST /workspace/catalog/compositions/{jobId}/discard` — borra el
  /// resultado. 409 si el job sigue en vuelo o el producto usa la imagen.
  Future<void> discard(String jobId);
}
