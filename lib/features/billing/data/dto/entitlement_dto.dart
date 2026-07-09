/// DTO del wire de `GET /workspace/billing` (entitlementDTO del backend).
///
/// Las claves viajan en snake_case, consistentes con el adaptador Go de
/// billing. Todos los campos son obligatorios: el backend encoda la foto
/// completa siempre (los slices como `[]`, nunca null) — un faltante es un
/// wire roto, no un caso a tolerar. Excepción: `trial_expired` es ADITIVO
/// (un backend anterior no lo encoda) y su ausencia degrada a false; presente
/// con tipo inválido sigue siendo wire roto. El mapper convierte DTO ⇄ entidad.
class EntitlementDto {
  const EntitlementDto({
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
    this.imageGen,
  });

  factory EntitlementDto.fromJson(Map<String, dynamic> json) {
    final planCode = json['plan_code'];
    final status = json['status'];
    // Aditivo: ausente ⇒ false (backend viejo); presente no-bool ⇒ roto.
    final trialExpired = json['trial_expired'] ?? false;
    final usedConversations = json['used_conversations'];
    final conversationCap = json['conversation_cap'];
    final withinQuota = json['within_quota'];
    final quotaExceeded = json['quota_exceeded'];
    final storageUsedMb = json['storage_used_mb'];
    final storageQuotaMb = json['storage_quota_mb'];
    if (planCode is! String ||
        status is! String ||
        trialExpired is! bool ||
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
      trialExpired: trialExpired,
      usedConversations: usedConversations,
      conversationCap: conversationCap,
      withinQuota: withinQuota,
      quotaExceeded: quotaExceeded,
      storageUsedMb: storageUsedMb,
      storageQuotaMb: storageQuotaMb,
      eligibleProviders: _stringList(json, 'eligible_providers'),
      features: _stringList(json, 'features'),
      imageGen: _imageGen(json),
    );
  }

  final String planCode;
  final String status;
  final bool trialExpired;
  final int usedConversations;
  final int conversationCap;
  final bool withinQuota;
  final bool quotaExceeded;
  final int storageUsedMb;
  final int storageQuotaMb;
  final List<String> eligibleProviders;
  final List<String> features;

  /// Consumo de generación de imágenes del periodo. ADITIVO como
  /// `trial_expired`: null cuando el backend aún no lo encoda. Viaja como dos
  /// claves planas en snake_case —`image_gen_used` e `image_gen_cap`—,
  /// consistente con el resto de este wire; el backend emite ambas o ninguna.
  final ImageGenDto? imageGen;
}

/// Consumo/tope de imágenes del wire: claves planas `image_gen_used` e
/// `image_gen_cap` (enteros), al mismo nivel que el resto del entitlement.
class ImageGenDto {
  const ImageGenDto({required this.used, required this.cap});

  final int used;
  final int cap;
}

/// Aditivo: ambas claves ausentes ⇒ null (backend viejo). Presentes deben ser
/// enteros; una sola o un tipo inválido es un wire roto (el backend emite el
/// par completo o nada).
ImageGenDto? _imageGen(Map<String, dynamic> json) {
  final used = json['image_gen_used'];
  final cap = json['image_gen_cap'];
  if (used == null && cap == null) return null;
  if (used is! int || cap is! int) {
    throw const FormatException(
      'entitlement: "image_gen_used"/"image_gen_cap" a medias o inválido',
    );
  }
  return ImageGenDto(used: used, cap: cap);
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
