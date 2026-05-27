/// Convención de días: la UI muestra L M X J V S D (lunes-primero, visual
/// español); el wire usa `time.Weekday` de Go — 0=Domingo .. 6=Sábado.
/// Sin un mapeo explícito es fácil intercambiar L y D silenciosamente y
/// que las ventanas se ejecuten en días equivocados.
///
/// `uiDayToWire(0)` = 1 (Lunes); `uiDayToWire(6)` = 0 (Domingo).
/// Fórmula compacta: `(ui + 1) % 7`.
int uiDayToWire(int ui) => (ui + 1) % 7;

/// Inversa: `wireDayToUi(0)` = 6 (Domingo va al final del visual);
/// `wireDayToUi(1)` = 0 (Lunes al principio).
/// Fórmula compacta: `(wire + 6) % 7` — equivalente a `(wire - 1 + 7) % 7`.
int wireDayToUi(int wire) => (wire + 6) % 7;

const List<String> _uiDayLabels = <String>['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// Etiqueta corta (1 carácter) para el chip del día en orden UI.
/// `X` para miércoles es la convención de calendarios en español; `M`
/// es martes (no miércoles). `J` jueves, `V` viernes, `S` sábado,
/// `D` domingo.
String uiDayLabel(int ui) => _uiDayLabels[ui];
