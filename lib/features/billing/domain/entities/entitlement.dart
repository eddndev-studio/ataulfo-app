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
    required this.usedConversations,
    required this.conversationCap,
    required this.withinQuota,
    required this.quotaExceeded,
    required this.storageUsedMb,
    required this.storageQuotaMb,
    required this.eligibleProviders,
    required this.features,
  });

  final String planCode;

  /// Estado de la suscripción tal cual el wire (active/trialing/past_due/…).
  final String status;

  /// Prueba vencida (trialing con el periodo ya cerrado) — llega YA derivado
  /// del backend, igual que los flags de cuota: `status` sigue diciendo
  /// 'trialing' y este bool explica por qué la IA está pausada.
  final bool trialExpired;

  /// Conversaciones CON IA consumidas en el periodo vigente del plan.
  final int usedConversations;

  /// Tope de conversaciones del periodo. 0 = ilimitado (flag del backend).
  final int conversationCap;

  final bool withinQuota;
  final bool quotaExceeded;

  final int storageUsedMb;

  /// Cupo de almacenamiento. 0 = ilimitado, misma convención que el cap.
  final int storageQuotaMb;

  /// Proveedores elegibles como cerebro conversacional (valores de wire).
  final Set<String> eligibleProviders;

  /// Features gateadas del plan (p.ej. 'media_gallery'), orden del backend.
  final List<String> features;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Entitlement &&
        other.planCode == planCode &&
        other.status == status &&
        other.trialExpired == trialExpired &&
        other.usedConversations == usedConversations &&
        other.conversationCap == conversationCap &&
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
    usedConversations,
    conversationCap,
    withinQuota,
    quotaExceeded,
    storageUsedMb,
    storageQuotaMb,
    // Suma de hashes: conmutativa, coherente con la igualdad por contenido
    // del set (dos órdenes de llegada producen el mismo hash).
    eligibleProviders.fold<int>(0, (acc, p) => acc + p.hashCode),
    Object.hashAll(features),
  );
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
