import 'dart:convert';

/// Un campo que cambió en una escritura: ruta, valor previo y nuevo (ya como
/// texto legible). Espejo del `fieldChange` del backend.
class PaFieldChange {
  const PaFieldChange({
    required this.field,
    required this.from,
    required this.to,
  });

  final String field;
  final String from;
  final String to;
}

/// Reemplazo textual anclado que devuelve edit_prompt/edit_doc. `context`
/// ubica el fragmento sin obligar a pintar el documento completo.
class PaTextDiff {
  const PaTextDiff({
    required this.oldText,
    required this.newText,
    required this.context,
  });

  final String oldText;
  final String newText;
  final String context;
}

/// Resultado de un tool, parseado del envelope `tool_results` del wire. El
/// envelope es jsonb crudo con claves snake_case (`tool_name`, `content`) y
/// `content` DOBLE-CODIFICADO: un string JSON con el output real del tool
/// (`{...summary, "changed":[...]}` en éxito, `{"error_kind":...}` en error).
class PaToolResult {
  const PaToolResult({
    required this.toolName,
    required this.changed,
    required this.errorKind,
    required this.bots,
    this.resourceName = '',
    this.diff,
  });

  final String toolName;
  final List<PaFieldChange> changed;
  final String errorKind;

  /// Nombres de los Bots impactados, sólo poblado en requires_confirmation.
  final List<String> bots;
  final String resourceName;
  final PaTextDiff? diff;

  /// Hay algo que valga la pena expandir (un changeset real o un error).
  bool get hasDetail =>
      changed.isNotEmpty || errorKind.isNotEmpty || diff != null;

  bool get requiresConfirmation => errorKind == 'requires_confirmation';

  static const PaToolResult _empty = PaToolResult(
    toolName: '',
    changed: <PaFieldChange>[],
    errorKind: '',
    bots: <String>[],
    resourceName: '',
  );

  static PaToolResult parse(String? raw) {
    if (raw == null || raw.isEmpty) return _empty;
    try {
      final outer = jsonDecode(raw);
      if (outer is! Map<String, dynamic>) return _empty;
      final toolName = outer['tool_name'] as String? ?? '';
      final inner = _innerContent(outer['content']);
      return PaToolResult(
        toolName: toolName,
        changed: _parseChanged(inner['changed']),
        errorKind: inner['error_kind'] as String? ?? '',
        bots: _parseBots(inner['bots']),
        resourceName:
            inner['name']?.toString() ?? inner['template_id']?.toString() ?? '',
        diff: _parseDiff(inner['diff']),
      );
    } on FormatException {
      // tool_results no es JSON: degrada a chip sin nombre.
      return _empty;
    }
  }

  static List<String> _parseBots(Object? raw) {
    if (raw is! List) return const <String>[];
    final out = <String>[];
    for (final b in raw) {
      if (b is Map<String, dynamic>) {
        final name = b['name']?.toString() ?? '';
        if (name.isNotEmpty) out.add(name);
      }
    }
    return out;
  }

  /// `content` normalmente es un string JSON (doble-codificado); se tolera que
  /// algún día llegue como objeto. Cualquier otra cosa ⇒ mapa vacío.
  static Map<String, dynamic> _innerContent(Object? content) {
    if (content is Map<String, dynamic>) return content;
    if (content is String && content.isNotEmpty) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) return decoded;
      } on FormatException {
        // content no-JSON (p. ej. un `{"status":"reacted"}` plano o texto):
        // sin detalle estructurado.
      }
    }
    return <String, dynamic>{};
  }

  static List<PaFieldChange> _parseChanged(Object? raw) {
    if (raw is! List) return const <PaFieldChange>[];
    final out = <PaFieldChange>[];
    for (final c in raw) {
      if (c is Map<String, dynamic>) {
        out.add(
          PaFieldChange(
            field: c['field']?.toString() ?? '',
            from: _fmt(c['from']),
            to: _fmt(c['to']),
          ),
        );
      }
    }
    return out;
  }

  static PaTextDiff? _parseDiff(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final oldText = raw['old']?.toString() ?? '';
    final newText = raw['new']?.toString() ?? '';
    final context = raw['context']?.toString() ?? '';
    if (oldText.isEmpty && newText.isEmpty) return null;
    return PaTextDiff(oldText: oldText, newText: newText, context: context);
  }

  /// Valor de un campo a texto: null ⇒ '∅' (distingue "vacío" de la cadena
  /// "null"); el resto, su representación natural.
  static String _fmt(Object? v) => v == null ? '∅' : v.toString();
}

/// Traduce un `error_kind` del backend a copy en español para el operador.
String paToolErrorCopy(String kind) {
  switch (kind) {
    case 'not_found':
      return 'No se encontró el recurso.';
    case 'version_conflict':
      return 'Conflicto de versión: alguien más lo cambió, reintenta.';
    case 'anchor_not_found':
      return 'El fragmento ya no existe. Volveré a leer antes de reintentar.';
    case 'anchor_not_unique':
      return 'El fragmento aparece varias veces; hace falta un ancla más específica.';
    case 'empty_anchor':
      return 'El reemplazo necesita un fragmento de referencia.';
    case 'no_change':
      return 'El reemplazo no produciría ningún cambio.';
    case 'already_exists':
      return 'Ese documento ya existe; hay que editarlo en lugar de crearlo.';
    case 'unavailable':
      return 'Esta capacidad no está disponible en este entorno.';
    case 'invalid_input':
      return 'Dato inválido por las reglas del negocio.';
    case 'invalid_args':
      return 'Argumentos inválidos para la herramienta.';
    case 'forbidden_for_role':
      return 'Tu rol no tiene permiso para esta acción.';
    case 'variable_in_use':
      return 'La variable está en uso por algún Canal.';
    case 'requires_confirmation':
      return 'Requiere confirmación antes de aplicar.';
    case 'unknown_tool':
      return 'Herramienta desconocida.';
    case 'builtin_error':
      return 'La herramienta falló.';
    default:
      return 'Error: $kind';
  }
}
