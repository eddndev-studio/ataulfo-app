import 'dart:typed_data';

/// Almacén local de bytes de media indexado por `ref` BARE.
///
/// El `ref` es opaco, estable e inmutable de por vida y embebe el tenant
/// (`tenant/<org>/media/<id>`), así que es una clave de cache perfecta: dos
/// orgs nunca colisionan y los bytes de un ref jamás cambian. Por eso este
/// cache NO tiene TTL — a diferencia de la metadata, cuyas `previewUrl`
/// firmadas expiran. Una vez en disco, los bytes sirven offline e ignorando la
/// vida de la firma.
abstract interface class MediaByteStore {
  /// Bytes cacheados para [ref], o `null` si nunca se escribieron (miss).
  Future<Uint8List?> read(String ref);

  /// Persiste [bytes] bajo [ref]. Sobrescribir es idempotente (el contenido de
  /// un ref es inmutable, así que reescribir los mismos bytes es inocuo).
  Future<void> write(String ref, Uint8List bytes);
}
