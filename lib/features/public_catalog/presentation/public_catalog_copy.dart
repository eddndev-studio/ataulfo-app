import '../domain/entities/catalog_appearance.dart';
import '../domain/failures/public_catalog_failure.dart';

/// Traduce una falla tipada a copy es-MX para la UI. Única frontera que conoce
/// las causas; la vista nunca arma texto a partir de un código de wire.
String publicCatalogFailureCopy(PublicCatalogFailure? f) => switch (f) {
  PublicCatalogNetworkFailure() =>
    'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
  PublicCatalogForbiddenFailure() =>
    'Solo un administrador puede cambiar el catálogo público.',
  PublicCatalogInvalidSlugFailure() =>
    'El enlace solo admite minúsculas, números y guiones (3 a 40 caracteres).',
  PublicCatalogInvalidAppearanceFailure() =>
    'Ese diseño o color ya no está disponible. Actualiza la app e inténtalo de '
        'nuevo.',
  PublicCatalogSlugTakenFailure() =>
    'Ese enlace ya lo usa otro negocio. Prueba con uno distinto.',
  PublicCatalogServerFailure() =>
    'El servidor tuvo un problema. Inténtalo más tarde.',
  PublicCatalogUnknownFailure() ||
  null => 'No se pudo completar la acción. Inténtalo de nuevo.',
};

// ── Apariencia ──────────────────────────────────────────────────────────────
// Copy es-MX de la sección que elige diseño + color primario del catálogo.

/// Título de la sección.
const String catalogAppearanceTitle = 'Apariencia';

/// Caption de la sección: qué controla y a dónde se aplica.
const String catalogAppearanceCaption =
    'Elige cómo se ve tu catálogo: un diseño y un color para toda la página.';

/// Aviso cuando el catálogo está apagado: la apariencia se guarda igual pero
/// solo se ve al encender la vitrina.
const String catalogAppearanceOffHint =
    'La apariencia se aplica cuando enciendes el catálogo.';

/// Encabezado del selector de diseño.
const String catalogDesignLabel = 'Diseño';

/// Encabezado del selector de color.
const String catalogAccentLabel = 'Color primario';

/// Marca del acento por defecto (identidad Ataúlfo), para el swatch mango.
const String catalogAccentDefaultTag = 'Predeterminado';

/// Nombre es-MX de un diseño.
String catalogDesignName(CatalogDesign design) => switch (design) {
  CatalogDesign.carta => 'Carta',
  CatalogDesign.mostrador => 'Mostrador',
  CatalogDesign.membrete => 'Membrete',
};

/// Descripción corta de un diseño (bajo su nombre en la tarjeta).
String catalogDesignDescription(CatalogDesign design) => switch (design) {
  CatalogDesign.carta => 'Como una carta impresa: sobrio y editorial.',
  CatalogDesign.mostrador => 'Cada categoría en su hoja, fácil de recorrer.',
  CatalogDesign.membrete => 'Tu marca al frente, con una banda de portada.',
};

/// Nombre es-MX de un color primario (etiqueta/tooltip del swatch).
String catalogAccentName(CatalogAccent accent) => switch (accent) {
  CatalogAccent.mango => 'Mango',
  CatalogAccent.olivo => 'Olivo',
  CatalogAccent.salvia => 'Salvia',
  CatalogAccent.petroleo => 'Petróleo',
  CatalogAccent.mar => 'Mar',
  CatalogAccent.cobalto => 'Cobalto',
  CatalogAccent.indigo => 'Índigo',
  CatalogAccent.ciruela => 'Ciruela',
  CatalogAccent.vino => 'Vino',
  CatalogAccent.arcilla => 'Arcilla',
  CatalogAccent.cacao => 'Cacao',
  CatalogAccent.grafito => 'Grafito',
  CatalogAccent.bosque => 'Bosque',
};
