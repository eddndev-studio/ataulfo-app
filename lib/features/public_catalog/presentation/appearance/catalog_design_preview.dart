import 'package:flutter/material.dart';

import '../../domain/entities/catalog_appearance.dart';
import 'accent_palette.dart';

/// Mini-vista pintada de un diseño del catálogo, teñida con el acento vigente.
/// No usa assets: es un [CustomPaint] que evoca la silueta de cada diseño
/// (carta editorial, hojas de mostrador, membrete con banda) sobre el papel
/// real de ese tema. Sirve de preview seleccionable; el realce de selección lo
/// pone el contenedor (la tarjeta), no esta pintura.
class CatalogDesignPreview extends StatelessWidget {
  const CatalogDesignPreview({
    super.key,
    required this.design,
    required this.accent,
  });

  final CatalogDesign design;
  final CatalogAccent accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: CustomPaint(
          painter: _CatalogDesignPainter(
            design: design,
            spec: accentSpec(accent),
          ),
          // Etiqueta estable para los tests del selector; el contenido es
          // decorativo (la etiqueta textual la pone la tarjeta).
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Papel de cada tema (el fondo real de la página web correspondiente).
const Map<CatalogDesign, Color> _paperOf = <CatalogDesign, Color>{
  CatalogDesign.carta: Color(0xFFF4F1E9),
  CatalogDesign.mostrador: Color(0xFFFAF8F5),
  CatalogDesign.membrete: Color(0xFFF7F6F4),
};

/// Tono de cuerpo (texto no acentuado) sobre el papel: un gris cálido oscuro.
const Color _ink = Color(0xFF3A352B);

class _CatalogDesignPainter extends CustomPainter {
  _CatalogDesignPainter({required this.design, required this.spec});

  final CatalogDesign design;
  final AccentSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final paper = _paperOf[design] ?? _paperOf[CatalogDesign.carta]!;
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    switch (design) {
      case CatalogDesign.carta:
        _paintCarta(canvas, size);
      case CatalogDesign.mostrador:
        _paintMostrador(canvas, size);
      case CatalogDesign.membrete:
        _paintMembrete(canvas, size);
    }
  }

  // «Carta» — menú editorial centrado: sello, título y filas nombre · precio
  // unidas por puntos conductores.
  void _paintCarta(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pad = w * 0.12;

    // Sello-monograma: anillo fino centrado arriba.
    final sealC = Offset(w / 2, h * 0.14);
    canvas.drawCircle(
      sealC,
      w * 0.07,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = spec.tinta,
    );

    // Título centrado (barra corta en tinta).
    _bar(
      canvas,
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.28),
        width: w * 0.44,
        height: 3,
      ),
      spec.tinta,
    );

    // Tres filas: nombre a la izquierda, puntos conductores, precio a la derecha.
    for (var i = 0; i < 3; i++) {
      final y = h * 0.46 + i * h * 0.16;
      _bar(canvas, Rect.fromLTWH(pad, y, w * 0.30, 2.5), _ink);
      _leaderDots(canvas, pad + w * 0.34, w - pad - w * 0.20, y + 1.25);
      _bar(
        canvas,
        Rect.fromLTWH(w - pad - w * 0.16, y, w * 0.16, 2.5),
        spec.tinta,
      );
    }
  }

  // «Mostrador» — hoja blanca redondeada con filas: thumb cuadrado + dos líneas.
  void _paintMostrador(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sheet = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.84, h * 0.84),
      const Radius.circular(9),
    );
    canvas.drawRRect(sheet, Paint()..color = Colors.white);
    canvas.drawRRect(
      sheet,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFE9E5DE),
    );

    final left = w * 0.16;
    final thumb = w * 0.20;
    for (var i = 0; i < 3; i++) {
      final top = h * 0.18 + i * h * 0.26;
      // Thumb cuadrado (acento vivo atenuado).
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, thumb, thumb),
          const Radius.circular(4),
        ),
        Paint()..color = spec.vivo.withValues(alpha: 0.35),
      );
      final tx = left + thumb + w * 0.06;
      _bar(canvas, Rect.fromLTWH(tx, top + thumb * 0.18, w * 0.34, 3), _ink);
      _bar(
        canvas,
        Rect.fromLTWH(tx, top + thumb * 0.60, w * 0.18, 3),
        spec.tinta,
      );
    }
  }

  // «Membrete» — banda de portada tintada con medallón y grilla de tarjetas.
  void _paintMembrete(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bandH = h * 0.36;

    // Banda hero: acento vivo muy diluido sobre el papel.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, bandH),
      Paint()..color = spec.vivo.withValues(alpha: 0.20),
    );

    // Medallón con doble bisel, centrado en la banda.
    final medC = Offset(w / 2, bandH * 0.52);
    canvas.drawCircle(medC, w * 0.11, Paint()..color = Colors.white);
    for (final r in <double>[w * 0.11, w * 0.075]) {
      canvas.drawCircle(
        medC,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = spec.tinta,
      );
    }

    // Grilla 2×2 de tarjetas bajo la banda.
    final gap = w * 0.06;
    final cardW = (w - gap * 3) / 2;
    final cardH = (h - bandH - gap * 3) / 2;
    for (var r = 0; r < 2; r++) {
      for (var c = 0; c < 2; c++) {
        final rect = Rect.fromLTWH(
          gap + c * (cardW + gap),
          bandH + gap + r * (cardH + gap),
          cardW,
          cardH,
        );
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
        canvas.drawRRect(rr, Paint()..color = Colors.white);
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFFE9E5DE),
        );
        // Barrita de acento dentro de cada tarjeta.
        _bar(
          canvas,
          Rect.fromLTWH(
            rect.left + rect.width * 0.18,
            rect.bottom - rect.height * 0.28,
            rect.width * 0.5,
            2.5,
          ),
          spec.tinta,
        );
      }
    }
  }

  void _bar(Canvas canvas, Rect rect, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = color,
    );
  }

  void _leaderDots(Canvas canvas, double x0, double x1, double y) {
    final paint = Paint()..color = _ink.withValues(alpha: 0.5);
    for (var x = x0; x <= x1; x += 4) {
      canvas.drawCircle(Offset(x, y), 0.7, paint);
    }
  }

  @override
  bool shouldRepaint(_CatalogDesignPainter old) =>
      old.design != design ||
      old.spec.tinta != spec.tinta ||
      old.spec.vivo != spec.vivo;
}
