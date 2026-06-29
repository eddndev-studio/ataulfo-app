import '../../../templates/data/dto/template_dto.dart';

/// DTO del wire de `GET/PUT /org/ai-config`.
///
/// `hosts` es un objeto idModelo→host (strings crudos). `defaults` reusa
/// [AiConfigDto] (la MISMA forma snake_case que `templates.ai`), así el cliente
/// no duplica el parse de AIConfig.
class OrgAiConfigResp {
  const OrgAiConfigResp({required this.hosts, required this.defaults});

  factory OrgAiConfigResp.fromJson(Map<String, dynamic> json) {
    final hostsRaw = json['hosts'];
    final defaults = json['defaults'];
    if (hostsRaw is! Map) {
      throw const FormatException(
        'orgAiConfig: clave obligatoria "hosts" ausente o tipo inválido',
      );
    }
    if (defaults is! Map<String, dynamic>) {
      throw const FormatException(
        'orgAiConfig: clave obligatoria "defaults" ausente o tipo inválido',
      );
    }
    final hosts = <String, String>{};
    hostsRaw.forEach((key, value) {
      if (key is String && value is String) {
        hosts[key] = value;
      }
    });
    return OrgAiConfigResp(
      hosts: hosts,
      defaults: AiConfigDto.fromJson(defaults),
    );
  }

  final Map<String, String> hosts;
  final AiConfigDto defaults;
}
