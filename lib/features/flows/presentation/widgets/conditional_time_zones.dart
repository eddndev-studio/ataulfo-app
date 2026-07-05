/// Zona horaria elegible del form CONDITIONAL_TIME: id IANA del wire y
/// nombre humano para el operador.
class CtTimezoneOption {
  const CtTimezoneOption(this.id, this.label);

  final String id;
  final String label;
}

/// Set curado de timezones que el operador puede elegir. Corto a propósito:
/// cubre LATAM principales + US este/oeste + España + UTC. El backend acepta
/// cualquier zona que `time.LoadLocation` resuelva, así que una tz válida
/// fuera de este set (escrita por otro cliente) se preserva y se ofrece como
/// "zona actual" en el selector; ampliar el set (o sustituirlo por un
/// autocomplete contra IANA) es trabajo aparte.
const List<CtTimezoneOption> ctCuratedTimezones = <CtTimezoneOption>[
  CtTimezoneOption('America/Mexico_City', 'Ciudad de México'),
  CtTimezoneOption('America/New_York', 'Nueva York'),
  CtTimezoneOption('America/Los_Angeles', 'Los Ángeles'),
  CtTimezoneOption('America/Bogota', 'Bogotá'),
  CtTimezoneOption('America/Buenos_Aires', 'Buenos Aires'),
  CtTimezoneOption('Europe/Madrid', 'Madrid'),
  CtTimezoneOption('UTC', 'UTC'),
];

/// Nombre humano de una tz curada; una tz fuera del set se muestra con su
/// id IANA crudo — visible y honesto, nunca un campo vacío.
String ctTimezoneLabel(String id) {
  for (final z in ctCuratedTimezones) {
    if (z.id == id) return z.label;
  }
  return id;
}
