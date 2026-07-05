import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_timeline_row.dart';

/// Franja entre filas del timeline: continúa la espina y, con inserción
/// habilitada, ofrece la zona de tap discreta con el glifo "+" (quieto en
/// gris apagado; se enciende al hover — en táctil el tap directo basta).
///
/// Interna al `AppStepTimeline`; pública solo para vivir en su propio
/// archivo con la familia de inserción.
class TimelineRowGap extends StatelessWidget {
  const TimelineRowGap({
    super.key,
    required this.insertIndex,
    required this.onInsertAt,
  });

  /// Alto de la franja cuando ofrece inserción.
  static const double height = 24.0;

  /// Posición que ocuparía lo insertado; null ⇒ franja sin inserción.
  final int? insertIndex;
  final void Function(int index)? onInsertAt;

  @override
  Widget build(BuildContext context) {
    final idx = insertIndex;
    final insert = onInsertAt;
    final interactive = idx != null && insert != null;
    return SizedBox(
      height: interactive ? height : AppTokens.sp3,
      child: Stack(
        children: <Widget>[
          const TimelineSpineBar(),
          if (interactive)
            Positioned.fill(
              left: AppTimelineRow.railWidth,
              child: _InsertZone(index: idx, onInsertAt: insert),
            ),
        ],
      ),
    );
  }
}

/// Zona de inserción entre filas: todo el ancho del contenido es
/// tappable, pero el único trazo visible es el glifo "+" discreto.
class _InsertZone extends StatefulWidget {
  const _InsertZone({required this.index, required this.onInsertAt});

  final int index;
  final void Function(int index) onInsertAt;

  @override
  State<_InsertZone> createState() => _InsertZoneState();
}

class _InsertZoneState extends State<_InsertZone> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? AppTokens.primary : AppTokens.textDisabled;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        label: 'Insertar paso aquí',
        child: InkWell(
          key: Key('app_step_timeline.insert.${widget.index}'),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          onTap: () => widget.onInsertAt(widget.index),
          child: Center(
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color),
              ),
              child: Icon(Icons.add, size: 12, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inserter del final del timeline, siempre visible: una fila fantasma
/// ("el siguiente paso va aquí") con borde hairline, sin fill — presente
/// sin competir con las filas reales.
class TimelineEndInserter extends StatelessWidget {
  const TimelineEndInserter({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(color: AppTokens.divider),
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.add, size: 18, color: AppTokens.text2),
            const SizedBox(width: AppTokens.sp2),
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
          ],
        ),
      ),
    );
  }
}
