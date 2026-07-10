/// Foto de entitlement de la org activa expuesta por `GET /workspace/billing`:
/// qué puede hacer la org AHORA MISMO (plan + estado de cobro + consumo del
/// periodo). Los flags de cuota (`withinQuota`, `quotaExceeded`) llegan YA
/// derivados del backend — el cliente no recalcula la semántica "cap 0 = ∞ /
/// used == cap ya excede" por su cuenta.
///
/// `eligibleProviders` viaja como strings crudos del wire (p.ej. 'MINIMAX'),
/// NO como `AIProvider`: su único consumo cliente es filtrar el catálogo de
/// modelos comparando contra `ProviderEntry.provider` (también wire crudo), y
/// el backend puede ganar un proveedor entre releases sin romper este parse.
class Entitlement {
  const Entitlement({
    required this.planCode,
    required this.status,
    required this.trialExpired,
    required this.creditsUsed,
    required this.creditCap,
    required this.withinQuota,
    required this.quotaExceeded,
    required this.storageUsedMb,
    required this.storageQuotaMb,
    required this.eligibleProviders,
    required this.features,
    this.imageGen,
  });

  final String planCode;

  /// Estado de la suscripción tal cual el wire (active/trialing/past_due/…).
  final String status;

  /// Prueba vencida (trialing con el periodo ya cerrado) — llega YA derivado
  /// del backend, igual que los flags de cuota: `status` sigue diciendo
  /// 'trialing' y este bool explica por qué la IA está pausada.
  final bool trialExpired;

  /// Créditos de IA consumidos en el periodo vigente del plan (mensual):
  /// cada respuesta ENTREGADA por el asistente pesa según su modelo.
  final int creditsUsed;

  /// Tope de créditos del periodo. 0 = ilimitado (flag del backend).
  final int creditCap;

  final bool withinQuota;
  final bool quotaExceeded;

  final int storageUsedMb;

  /// Cupo de almacenamiento. 0 = ilimitado, misma convención que el cap.
  final int storageQuotaMb;

  /// Proveedores elegibles como cerebro conversacional (valores de wire).
  final Set<String> eligibleProviders;

  /// Features gateadas del plan (p.ej. 'media_gallery'), orden del backend.
  final List<String> features;

  /// Consumo de imágenes generadas con IA del periodo (mensual). Null cuando
  /// el backend aún no expone el bloque: la UI omite el contador, no lo
  /// inventa en cero.
  final ImageGenUsage? imageGen;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Entitlement &&
        other.imageGen == imageGen &&
        other.planCode == planCode &&
        other.status == status &&
        other.trialExpired == trialExpired &&
        other.creditsUsed == creditsUsed &&
        other.creditCap == creditCap &&
        other.withinQuota == withinQuota &&
        other.quotaExceeded == quotaExceeded &&
        other.storageUsedMb == storageUsedMb &&
        other.storageQuotaMb == storageQuotaMb &&
        _setEquals(other.eligibleProviders, eligibleProviders) &&
        _listEquals(other.features, features);
  }

  @override
  int get hashCode => Object.hash(
    planCode,
    status,
    trialExpired,
    creditsUsed,
    creditCap,
    withinQuota,
    quotaExceeded,
    storageUsedMb,
    storageQuotaMb,
    // Suma de hashes: conmutativa, coherente con la igualdad por contenido
    // del set (dos órdenes de llegada producen el mismo hash).
    eligibleProviders.fold<int>(0, (acc, p) => acc + p.hashCode),
    Object.hashAll(features),
    imageGen,
  );
}

/// Consumo de generación de imágenes del periodo. Cap 0 = ilimitado, misma
/// convención que los demás topes del entitlement.
class ImageGenUsage {
  const ImageGenUsage({required this.used, required this.cap});

  final int used;
  final int cap;

  @override
  bool operator ==(Object other) =>
      other is ImageGenUsage && other.used == used && other.cap == cap;

  @override
  int get hashCode => Object.hash(used, cap);
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
