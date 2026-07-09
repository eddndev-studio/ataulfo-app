/// DTO del wire de un job de composición de fondo
/// (`GET /workspace/catalog/products/{id}/compositions`).
///
/// Las claves viajan en camelCase, como el resto del adaptador Go del
/// catálogo. Todos los campos son obligatorios y el backend los emite
/// siempre ('' para modelo estándar, resultado pendiente o sin error): un
/// faltante o un tipo inválido es un wire roto, no un caso a tolerar.
/// `status` y `createdAt` se quedan como strings; el mapper los convierte.
class CompositionJobDto {
  const CompositionJobDto({
    required this.id,
    required this.preset,
    required this.model,
    required this.status,
    required this.resultMediaRef,
    required this.errorNote,
    required this.createdAt,
  });

  factory CompositionJobDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final preset = json['preset'];
    final model = json['model'];
    final status = json['status'];
    final resultMediaRef = json['resultMediaRef'];
    final errorNote = json['errorNote'];
    final createdAt = json['createdAt'];
    if (id is! String ||
        preset is! String ||
        model is! String ||
        status is! String ||
        resultMediaRef is! String ||
        errorNote is! String ||
        createdAt is! String) {
      throw const FormatException(
        'composición: clave obligatoria ausente o tipo inválido',
      );
    }
    return CompositionJobDto(
      id: id,
      preset: preset,
      model: model,
      status: status,
      resultMediaRef: resultMediaRef,
      errorNote: errorNote,
      createdAt: createdAt,
    );
  }

  final String id;
  final String preset;
  final String model;
  final String status;
  final String resultMediaRef;
  final String errorNote;
  final String createdAt;
}
