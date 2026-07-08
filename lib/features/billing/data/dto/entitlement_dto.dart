/// DTO del wire de `GET /workspace/billing` (entitlementDTO del backend).
///
/// Las claves viajan en snake_case, consistentes con el adaptador Go de
/// billing. Todos los campos son obligatorios: el backend encoda la foto
/// completa siempre (los slices como `[]`, nunca null) — un faltante es un
/// wire roto, no un caso a tolerar. El mapper convierte DTO ⇄ entidad.
class EntitlementDto {
  const EntitlementDto({
    required this.planCode,
    required this.status,
    required this.usedConversations,
    required this.conversationCap,
    required this.withinQuota,
    required this.quotaExceeded,
    required this.storageUsedMb,
    required this.storageQuotaMb,
    required this.eligibleProviders,
    required this.features,
  });

  factory EntitlementDto.fromJson(Map<String, dynamic> json) {
    final planCode = json['plan_code'];
    final status = json['status'];
    final usedConversations = json['used_conversations'];
    final conversationCap = json['conversation_cap'];
    final withinQuota = json['within_quota'];
    final quotaExceeded = json['quota_exceeded'];
    final storageUsedMb = json['storage_used_mb'];
    final storageQuotaMb = json['storage_quota_mb'];
    if (planCode is! String ||
        status is! String ||
        usedConversations is! int ||
        conversationCap is! int ||
        withinQuota is! bool ||
        quotaExceeded is! bool ||
        storageUsedMb is! int ||
        storageQuotaMb is! int) {
      throw const FormatException(
        'entitlement: clave obligatoria ausente o tipo inválido',
      );
    }
    return EntitlementDto(
      planCode: planCode,
      status: status,
      usedConversations: usedConversations,
      conversationCap: conversationCap,
      withinQuota: withinQuota,
      quotaExceeded: quotaExceeded,
      storageUsedMb: storageUsedMb,
      storageQuotaMb: storageQuotaMb,
      eligibleProviders: _stringList(json, 'eligible_providers'),
      features: _stringList(json, 'features'),
    );
  }

  final String planCode;
  final String status;
  final int usedConversations;
  final int conversationCap;
  final bool withinQuota;
  final bool quotaExceeded;
  final int storageUsedMb;
  final int storageQuotaMb;
  final List<String> eligibleProviders;
  final List<String> features;
}

/// Lista de strings obligatoria: no-lista o elemento no-string es un wire
/// roto (el backend tipa `[]string`); degradar en silencio escondería el bug.
List<String> _stringList(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! List) {
    throw FormatException('entitlement: "$key" debe ser lista');
  }
  return raw
      .map((e) {
        if (e is! String) {
          throw FormatException(
            'entitlement: "$key" trae un elemento no-string',
          );
        }
        return e;
      })
      .toList(growable: false);
}
