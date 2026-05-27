import 'dart:convert';

/// Shape de `Step.metadata` para CONDITIONAL_TIME (S11). El runner del
/// backend evalúa "now ∈ alguna ventana" y bifurca al `order` indicado.
/// El cliente edita el shape literal — esta entity es la representación
/// tipada del JSON opaco que viaja en el wire.
///
/// Wire keys son **snake_case** (`tz`, `windows`, `on_match_order`,
/// `on_else_order`, `days`, `from`, `to`) — inconsistente con el resto de
/// camelCase de Flows (mediaRef/delayMs/...). Se espeja el wire actual del
/// backend; cualquier cambio en `step_metadata.go` debe replicarse acá.
///
/// Convención de días: `time.Weekday` (0=Domingo .. 6=Sábado). La UI hace
/// el mapeo a chips L-M-X-J-V-S-D en presentation; el dominio se mantiene
/// agnóstico de cómo se etiquetan en pantalla.
///
/// `from`/`to` son `"HH:MM"` 24h en la TZ del metadata. `to` es exclusivo
/// y `from < to` estricto (sin overnight v1 — una ventana 22:00-04:00
/// parte en dos: 22:00-23:59 y 00:00-04:00).
class ConditionalTimeMetadata {
  const ConditionalTimeMetadata({
    required this.tz,
    required this.windows,
    required this.onMatchOrder,
    required this.onElseOrder,
  });

  final String tz;
  final List<TimeWindow> windows;
  final int onMatchOrder;
  final int onElseOrder;

  /// Decodifica + valida el shape. Cualquier desviación (json malformado,
  /// tz vacía, windows lista vacía, order negativo, día fuera de [0..6],
  /// HH:MM mal formado o fuera de rango, from >= to) ⇒ `FormatException`
  /// con mensaje específico. El caller traduce a copy de UI o failure.
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
    final onMatch = decoded['on_match_order'];
    if (onMatch is! int || onMatch < 0) {
      throw const FormatException(
        'conditional_time metadata: on_match_order negativo o ausente',
      );
    }
    final onElse = decoded['on_else_order'];
    if (onElse is! int || onElse < 0) {
      throw const FormatException(
        'conditional_time metadata: on_else_order negativo o ausente',
      );
    }
    return ConditionalTimeMetadata(
      tz: tz,
      windows: windows,
      onMatchOrder: onMatch,
      onElseOrder: onElse,
    );
  }

  /// Serializa al shape canónico del wire (snake_case). El caller pasa el
  /// resultado a `patchStep(metadataJson:)` / `createStep`.
  String toJsonString() => jsonEncode(<String, dynamic>{
    'tz': tz,
    'windows': windows
        .map(
          (w) => <String, dynamic>{'days': w.days, 'from': w.from, 'to': w.to},
        )
        .toList(),
    'on_match_order': onMatchOrder,
    'on_else_order': onElseOrder,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ConditionalTimeMetadata) return false;
    if (other.tz != tz) return false;
    if (other.onMatchOrder != onMatchOrder) return false;
    if (other.onElseOrder != onElseOrder) return false;
    if (other.windows.length != windows.length) return false;
    for (var i = 0; i < windows.length; i++) {
      if (other.windows[i] != windows[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(tz, onMatchOrder, onElseOrder, Object.hashAll(windows));
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
    throw FormatException(
      'conditional_time metadata: window $index sin days',
    );
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
