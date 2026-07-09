import 'package:flutter/material.dart';

/// Motivo de sticker ofrecido al operador. El [id] es el valor FIJO del wire;
/// [label] es el rótulo es-MX; [icon] evoca el motivo en el selector (no hay
/// assets binarios — el dibujo real lo fabrica el backend).
class StickerMotif {
  const StickerMotif({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

/// Catálogo cerrado de motivos, en el orden en que se ofrecen. Los ids y
/// rótulos son contrato con el backend (dominio stickers).
const List<StickerMotif> stickerMotifs = <StickerMotif>[
  StickerMotif(
    id: 'gracias',
    label: '¡Gracias!',
    icon: Icons.thumb_up_outlined,
  ),
  StickerMotif(
    id: 'pedido-listo',
    label: 'Pedido listo',
    icon: Icons.inventory_2_outlined,
  ),
  StickerMotif(
    id: 'en-camino',
    label: 'En camino',
    icon: Icons.delivery_dining_outlined,
  ),
  StickerMotif(
    id: 'bienvenido',
    label: 'Bienvenida',
    icon: Icons.waving_hand_outlined,
  ),
  StickerMotif(
    id: 'oferta',
    label: '¡Oferta!',
    icon: Icons.local_offer_outlined,
  ),
  StickerMotif(
    id: 'felicidades',
    label: '¡Felicidades!',
    icon: Icons.celebration_outlined,
  ),
  StickerMotif(
    id: 'corazon',
    label: 'Con cariño',
    icon: Icons.favorite_outline,
  ),
  StickerMotif(id: 'ok', label: '¡Va!', icon: Icons.thumb_up_alt_outlined),
];

/// Rótulo humano de un motivo por su id de wire; un id fuera del catálogo
/// (backend más nuevo) se muestra tal cual antes que esconder el sticker.
String stickerMotifLabel(String id) {
  for (final m in stickerMotifs) {
    if (m.id == id) return m.label;
  }
  return id;
}
