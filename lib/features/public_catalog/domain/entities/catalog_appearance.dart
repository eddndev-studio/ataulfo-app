// Apariencia del catálogo público: el diseño predefinido y el color primario
// que la org elige para su vitrina. Ambos viajan como ids estables en el wire
// (`design`, `accent`); un valor ausente, no-string o fuera del enum cae al
// default (fail-open) para que cachés viejas y despliegues cruzados nunca
// rompan la vista.

/// Diseño predefinido del catálogo (`design` en el wire). Default [carta].
enum CatalogDesign {
  carta,
  mostrador,
  membrete;

  /// Id estable del wire (coincide con el nombre del valor).
  String get wire => name;

  /// Resuelve un valor del wire; ausente, no-string o fuera del enum ⇒ [carta].
  static CatalogDesign fromWire(Object? value) {
    for (final d in values) {
      if (d.name == value) return d;
    }
    return carta;
  }
}

/// Color primario del catálogo (`accent` en el wire). Default [mango]
/// (identidad Ataúlfo cuando la org no eligió otro).
enum CatalogAccent {
  mango,
  olivo,
  salvia,
  petroleo,
  mar,
  cobalto,
  indigo,
  ciruela,
  vino,
  arcilla,
  cacao,
  grafito,
  bosque;

  /// Id estable del wire (coincide con el nombre del valor).
  String get wire => name;

  /// Resuelve un valor del wire; ausente, no-string o fuera del enum ⇒ [mango].
  static CatalogAccent fromWire(Object? value) {
    for (final a in values) {
      if (a.name == value) return a;
    }
    return mango;
  }
}
