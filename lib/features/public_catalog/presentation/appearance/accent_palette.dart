import 'package:flutter/painting.dart';

import '../../domain/entities/catalog_appearance.dart';

/// Par de colores de un acento del catálogo: [tinta] (texto/enlaces/anillos,
/// el tono oscuro) y [vivo] (superficies, swatches, detalles). Validados AA
/// sobre los papeles de los tres diseños.
class AccentSpec {
  const AccentSpec({required this.tinta, required this.vivo});

  final Color tinta;
  final Color vivo;
}

/// Resuelve el par tinta/vivo de un [CatalogAccent]. Es la única fuente de los
/// hex de la vitrina en el cliente; la copy (nombres es-MX) vive aparte, en
/// `public_catalog_copy.dart`.
const Map<CatalogAccent, AccentSpec> catalogAccentPalette =
    <CatalogAccent, AccentSpec>{
      CatalogAccent.mango: AccentSpec(
        tinta: Color(0xFF8A5200),
        vivo: Color(0xFFFFA51F),
      ),
      CatalogAccent.olivo: AccentSpec(
        tinta: Color(0xFF55652F),
        vivo: Color(0xFF97AD62),
      ),
      CatalogAccent.salvia: AccentSpec(
        tinta: Color(0xFF46685A),
        vivo: Color(0xFF8FB4A3),
      ),
      CatalogAccent.petroleo: AccentSpec(
        tinta: Color(0xFF235955),
        vivo: Color(0xFF5BA8A2),
      ),
      CatalogAccent.mar: AccentSpec(
        tinta: Color(0xFF275A7C),
        vivo: Color(0xFF6AA5C9),
      ),
      CatalogAccent.cobalto: AccentSpec(
        tinta: Color(0xFF3C5288),
        vivo: Color(0xFF8FA7D9),
      ),
      CatalogAccent.indigo: AccentSpec(
        tinta: Color(0xFF43466F),
        vivo: Color(0xFF9093C9),
      ),
      CatalogAccent.ciruela: AccentSpec(
        tinta: Color(0xFF6D3F5F),
        vivo: Color(0xFFB585A7),
      ),
      CatalogAccent.vino: AccentSpec(
        tinta: Color(0xFF7C3242),
        vivo: Color(0xFFC97888),
      ),
      CatalogAccent.arcilla: AccentSpec(
        tinta: Color(0xFF8C4034),
        vivo: Color(0xFFD18A7D),
      ),
      CatalogAccent.cacao: AccentSpec(
        tinta: Color(0xFF6B4D39),
        vivo: Color(0xFFAB8A70),
      ),
      CatalogAccent.grafito: AccentSpec(
        tinta: Color(0xFF3F4959),
        vivo: Color(0xFF94A3B8),
      ),
      CatalogAccent.bosque: AccentSpec(
        tinta: Color(0xFF35593F),
        vivo: Color(0xFF7DAB8D),
      ),
    };

/// El par de un acento; nunca null (el mapa cubre los 13 valores del enum).
AccentSpec accentSpec(CatalogAccent accent) => catalogAccentPalette[accent]!;
