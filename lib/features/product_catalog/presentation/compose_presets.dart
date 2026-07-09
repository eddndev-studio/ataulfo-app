import 'package:flutter/material.dart';

/// Preset de escena para la composición de fondos. El [id] es el valor FIJO
/// del wire; [label] es el rótulo es-MX del producto. [colors] alimenta el
/// preview estático del selector: un degradado que EVOCA la escena (no hay
/// assets binarios; la escena real la fabrica el backend).
class ComposePreset {
  const ComposePreset({
    required this.id,
    required this.label,
    required this.colors,
  });

  final String id;
  final String label;
  final List<Color> colors;
}

/// Catálogo cerrado de escenas, en el orden en que se ofrecen. Los ids y
/// rótulos son contrato con el backend/producto; los colores solo evocan.
const List<ComposePreset> composePresets = <ComposePreset>[
  ComposePreset(
    id: 'estudio-blanco',
    label: 'Estudio blanco',
    colors: <Color>[Color(0xFFFAFAF9), Color(0xFFD6D3D1)],
  ),
  ComposePreset(
    id: 'marmol',
    label: 'Mármol',
    colors: <Color>[Color(0xFFE7E5E4), Color(0xFFF5F5F4), Color(0xFF9CA3AF)],
  ),
  ComposePreset(
    id: 'madera',
    label: 'Madera cálida',
    colors: <Color>[Color(0xFFB08159), Color(0xFF6F4A2F)],
  ),
  ComposePreset(
    id: 'degradado',
    label: 'Degradado suave',
    colors: <Color>[Color(0xFFFBCFE8), Color(0xFFBFDBFE)],
  ),
  ComposePreset(
    id: 'exterior',
    label: 'Exterior luminoso',
    colors: <Color>[Color(0xFF93C5FD), Color(0xFFFDE68A)],
  ),
];

/// Rótulo humano de un preset por su id de wire; un id fuera del catálogo
/// (backend más nuevo) se muestra tal cual antes que esconder el job.
String composePresetLabel(String id) {
  for (final p in composePresets) {
    if (p.id == id) return p.label;
  }
  return id;
}
