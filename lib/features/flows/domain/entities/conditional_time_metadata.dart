import 'dart:convert';

/// Shape de `Step.metadata` para CONDITIONAL_TIME. El runner del backend
/// evalúa "now ∈ alguna ventana" y bifurca al destino indicado.
///
/// Destinos — dos shapes en el wire:
/// - **Canónico por id** (`on_match_step_id`/`on_else_step_id`): la
///   identidad del step destino sobrevive reorders/borrados/inserciones.
///   Es lo ÚNICO que este cliente emite al guardar.
/// - **Posicional legacy** (`on_match_order`/`on_else_order`): filas no
///   migradas, y claves que el backend SINTETIZA en el listado junto a los
///   ids para clientes viejos. Se parsean si están (display/back-compat)
///   pero jamás se re-emiten cuando hay ids.
///
/// Wire keys son **snake_case** — espeja `step_metadata.go`; cualquier
/// cambio allá debe replicarse acá.
///
/// Convención de días: `time.Weekday` (0=Domingo .. 6=Sábado). La UI hace
/// el mapeo a chips L-M-X-J-V-S-D en presentation.
///
/// `from`/`to` son `"HH:MM"` 24h en la TZ del metadata. `to` es exclusivo
/// y `from < to` estricto (sin overnight v1 — una ventana 22:00-04:00
/// parte en dos: 22:00-23:59 y 00:00-04:00).
class ConditionalTimeMetadata {
  const ConditionalTimeMetadata({
    required this.tz,
    required this.windows,
    this.onMatchStepId,
    this.onElseStepId,
    this.onMatchOrder,
    this.onElseOrder,
  });

  final String tz;
  final List<TimeWindow> windows;

  /// Id del step destino cuando la ventana matchea. Par con
  /// [onElseStepId]: ambos-o-ninguno (lo garantiza el parse).
  final String? onMatchStepId;
  final String? onElseStepId;

  /// Destinos posicionales legacy: presentes en filas no migradas y como
  /// claves sintetizadas por el backend junto a los ids. Solo display.
  final int? onMatchOrder;
  final int? onElseOrder;

  /// Reporta si el metadata trae destinos por id (shape canónico).
  bool get hasStepIdRefs => onMatchStepId != null;

  /// Decodifica + valida el shape. Reglas de destino: par de ids completo
  /// (canónico), o par de orders completo (legacy). Un solo id, o un solo
  /// order sin ids, es shape a medias ⇒ `FormatException`. tz/ventanas/
  /// HH:MM se validan igual en ambos shapes.
  static ConditionalTimeMetadata fromJsonString(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw FormatException('conditional_time metadata: json: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('conditional_time metadata: no es objeto');
    }
    final tz = decoded['tz'];
    if (tz is! String || tz.isEmpty) {
      throw const FormatException('conditional_time metadata: tz vacía');
    }
    final windowsRaw = decoded['windows'];
    if (windowsRaw is! List || windowsRaw.isEmpty) {
      throw const FormatException('conditional_time metadata: sin ventanas');
    }
    final windows = <TimeWindow>[];
    for (var i = 0; i < windowsRaw.length; i++) {
      windows.add(_parseWindow(windowsRaw[i], i));
    }

    final matchId = _optionalId(decoded, 'on_match_step_id');
    final elseId = _optionalId(decoded, 'on_else_step_id');
    if ((matchId == null) != (elseId == null)) {
      throw const FormatException(
        'conditional_time metadata: destino por id incompleto',
      );
    }
    final matchOrder = _optionalOrder(decoded, 'on_match_order');
    final elseOrder = _optionalOrder(decoded, 'on_else_order');
    if (matchId == null) {
      // Shape legacy: el par posicional es obligatorio.
      if (matchOrder == null || elseOrder == null) {
        throw const FormatException(
          'conditional_time metadata: sin destinos (ni ids ni orders)',
        );
      }
    }
    return ConditionalTimeMetadata(
      tz: tz,
      windows: windows,
      onMatchStepId: matchId,
      onElseStepId: elseId,
      onMatchOrder: matchOrder,
      onElseOrder: elseOrder,
    );
  }

  static String? _optionalId(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) return null;
    if (v is! String || v.trim().isEmpty) {
      throw FormatException('conditional_time metadata: $key inválido');
    }
    return v;
  }

  static int? _optionalOrder(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) return null;
    if (v is! int || v < 0) {
      throw FormatException('conditional_time metadata: $key inválido: $v');
    }
    return v;
  }

  /// Serializa al shape canónico del wire. Con ids presentes emite
  /// id-form PURO (los orders son carga muerta para el backend nuevo y
  /// re-emitirlos arrastraría posiciones stale); sin ids conserva el
  /// shape posicional (no inventa destinos).
  String toJsonString() {
    final m = <String, dynamic>{
      'tz': tz,
      'windows': windows
          .map(
            (w) => <String, dynamic>{
              'days': w.days,
              'from': w.from,
              'to': w.to,
            },
          )
          .toList(),
    };
    if (hasStepIdRefs) {
      m['on_match_step_id'] = onMatchStepId;
      m['on_else_step_id'] = onElseStepId;
    } else {
      m['on_match_order'] = onMatchOrder;
      m['on_else_order'] = onElseOrder;
    }
    return jsonEncode(m);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ConditionalTimeMetadata) return false;
    if (other.tz != tz) return false;
    if (other.onMatchStepId != onMatchStepId) return false;
    if (other.onElseStepId != onElseStepId) return false;
    if (other.onMatchOrder != onMatchOrder) return false;
    if (other.onElseOrder != onElseOrder) return false;
    if (other.windows.length != windows.length) return false;
    for (var i = 0; i < windows.length; i++) {
      if (other.windows[i] != windows[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    tz,
    onMatchStepId,
    onElseStepId,
    onMatchOrder,
    onElseOrder,
    Object.hashAll(windows),
  );
}

/// Franja recurrente día+hora dentro de un `ConditionalTimeMetadata`.
/// `days` usa la convención `time.Weekday` (0=Domingo..6=Sábado).
/// `from`/`to` son `"HH:MM"` 24h en la TZ del metadata padre.
class TimeWindow {
  const TimeWindow({required this.days, required this.from, required this.to});

  final List<int> days;
  final String from;
  final String to;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TimeWindow) return false;
    if (other.from != from) return false;
    if (other.to != to) return false;
    if (other.days.length != days.length) return false;
    for (var i = 0; i < days.length; i++) {
      if (other.days[i] != days[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(from, to, Object.hashAll(days));
}

TimeWindow _parseWindow(Object? raw, int index) {
  if (raw is! Map<String, dynamic>) {
    throw FormatException(
      'conditional_time metadata: window $index no es objeto',
    );
  }
  final daysRaw = raw['days'];
  if (daysRaw is! List || daysRaw.isEmpty) {
    throw FormatException('conditional_time metadata: window $index sin days');
  }
  final days = <int>[];
  for (final d in daysRaw) {
    if (d is! int || d < 0 || d > 6) {
      throw FormatException(
        'conditional_time metadata: window $index day fuera de rango [0..6]: $d',
      );
    }
    days.add(d);
  }
  // Normalizamos a orden ascendente para que `==` por valor sea robusto
  // independiente de quién serializó el JSON (Flutter ordena, pero un
  // script de seed o un escritor terceros podría no hacerlo).
  days.sort();
  final from = raw['from'];
  final to = raw['to'];
  if (from is! String || to is! String) {
    throw FormatException(
      'conditional_time metadata: window $index from/to no son string',
    );
  }
  final fromMin = _parseHHMM(from, 'window $index from');
  final toMin = _parseHHMM(to, 'window $index to');
  if (fromMin >= toMin) {
    throw FormatException(
      'conditional_time metadata: window $index from >= to ($from >= $to)',
    );
  }
  return TimeWindow(days: days, from: from, to: to);
}

/// Parsea `"HH:MM"` 24h a total de minutos desde 00:00. Espejo de
/// `parseHHMM` en `step_metadata.go` — rangos [0..23] / [0..59], cualquier
/// otra cosa rompe con `FormatException`.
int _parseHHMM(String s, String label) {
  final parts = s.split(':');
  if (parts.length != 2) {
    throw FormatException(
      'conditional_time metadata: $label formato HH:MM esperado: "$s"',
    );
  }
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) {
    throw FormatException(
      'conditional_time metadata: $label HH:MM no numérico: "$s"',
    );
  }
  if (h < 0 || h > 23 || m < 0 || m > 59) {
    throw FormatException(
      'conditional_time metadata: $label HH:MM fuera de rango: "$s"',
    );
  }
  return h * 60 + m;
}
