import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_timeline_row.dart';

/// Salto de rama entre dos filas de un `AppStepTimeline`: la fila [from]
/// deriva el control hacia la fila [to] (siempre hacia ADELANTE) y el
/// conector se dibuja en el margen izquierdo del timeline, rematado en la
/// fila destino con una pill que lleva el [label] ("si cumple", "si no").
///
/// El salto es geometría pura para el kit: qué significa cada rama lo
/// decide el consumidor al derivar sus saltos del dominio.
class TimelineJump {
  const TimelineJump({
    required this.from,
    required this.to,
    required this.label,
  }) : assert(from < to, 'un salto conecta hacia adelante: from < to');

  /// Índice de la fila origen (donde nace el conector).
  final int from;

  /// Índice de la fila destino (donde remata la pill etiquetada).
  final int to;

  /// Etiqueta corta de la rama, pintada en la pill de llegada.
  final String label;
}

/// Asigna un carril del margen a cada salto (coloreo greedy de
/// intervalos): dos saltos cuyos rangos de filas se tocan NUNCA comparten
/// carril — con 2+ saltos simultáneos cada conector conserva su vertical
/// propia y el margen se lee sin ensalada. El carril 0 es el más cercano
/// al contenido; compartir una fila extrema (llegar y salir de la misma)
/// también separa carriles, a propósito: es donde los codos se amontonan.
List<int> timelineJumpLanes(List<TimelineJump> jumps) {
  final lanes = List<int>.filled(jumps.length, 0);
  for (var i = 0; i < jumps.length; i++) {
    final used = <int>{
      for (var k = 0; k < i; k++)
        if (jumps[i].from <= jumps[k].to && jumps[k].from <= jumps[i].to)
          lanes[k],
    };
    var lane = 0;
    while (used.contains(lane)) {
      lane++;
    }
    lanes[i] = lane;
  }
  return lanes;
}

/// Papel de un salto al cruzar UNA fila concreta del timeline. Cada item
/// pinta solo su rebanada del conector; la continuidad vertical entre
/// items la garantiza que las rebanadas se toquen en los bordes.
enum TimelineJumpRole {
  /// La fila origen: codo que sale del bullet hacia el carril y baja.
  exit,

  /// Fila intermedia: vertical del carril de borde a borde.
  through,

  /// La fila destino: vertical que remata en el codo de llegada + flecha.
  arrive,
}

/// Rebanada de un salto sobre una fila: su carril y su papel ahí.
typedef TimelineJumpSegment = ({int lane, TimelineJumpRole role});

/// Rebanadas de todos los [jumps] que cruzan la fila [index], con el
/// carril ya asignado por [lanes] (mismo orden que [jumps]).
List<TimelineJumpSegment> timelineJumpSegmentsAt(
  int index,
  List<TimelineJump> jumps,
  List<int> lanes,
) {
  final out = <TimelineJumpSegment>[];
  for (var i = 0; i < jumps.length; i++) {
    final j = jumps[i];
    if (index == j.from) {
      out.add((lane: lanes[i], role: TimelineJumpRole.exit));
    } else if (index == j.to) {
      out.add((lane: lanes[i], role: TimelineJumpRole.arrive));
    } else if (index > j.from && index < j.to) {
      out.add((lane: lanes[i], role: TimelineJumpRole.through));
    }
  }
  return out;
}

/// Separación horizontal entre carriles del margen.
const double _laneGap = 10.0;

/// Aire entre el carril más externo y el borde izquierdo del timeline.
const double _lanePad = 6.0;

/// Ancho del margen de saltos para [laneCount] carriles. 0 carriles = sin
/// margen: un timeline sin saltos no paga espacio por la posibilidad.
double timelineJumpGutterWidth(int laneCount) =>
    laneCount == 0 ? 0 : _lanePad * 2 + (laneCount - 1) * _laneGap;

/// X del carril [lane] dentro de un margen de ancho [gutterWidth]. El
/// carril 0 queda pegado al contenido; los siguientes crecen hacia afuera.
double _laneX(int lane, double gutterWidth) =>
    gutterWidth - _lanePad - lane * _laneGap;

/// Pinta las rebanadas de conector que cruzan UNA fila del timeline:
/// codo de salida (desde el eje del bullet hacia el carril), verticales
/// de paso y codo de llegada con flecha apuntando a la pill de la rama.
/// Se monta como fondo del item (CustomPaint painter), así que las líneas
/// pasan por DEBAJO del bullet y de la pill — que las tapan con su fill.
class TimelineJumpPainter extends CustomPainter {
  const TimelineJumpPainter({
    required this.segments,
    required this.gutterWidth,
    required this.exitY,
    required this.arriveY,
  });

  final List<TimelineJumpSegment> segments;
  final double gutterWidth;

  /// Y del codo de salida (el centro del bullet de la fila origen).
  final double exitY;

  /// Y del codo de llegada (el centro de la franja de pills de llegada).
  final double arriveY;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppTokens.text2
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final seg in segments) {
      final x = _laneX(seg.lane, gutterWidth);
      switch (seg.role) {
        case TimelineJumpRole.exit:
          // Sale del eje del bullet, cruza el margen y baja por su carril.
          final path = Path()
            ..moveTo(gutterWidth + AppTimelineRow.railWidth / 2, exitY)
            ..lineTo(x, exitY)
            ..lineTo(x, size.height);
          canvas.drawPath(path, line);
        case TimelineJumpRole.through:
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
        case TimelineJumpRole.arrive:
          final tipX = gutterWidth + AppTimelineRow.railWidth / 2 - 8;
          final path = Path()
            ..moveTo(x, 0)
            ..lineTo(x, arriveY)
            ..lineTo(tipX, arriveY);
          canvas.drawPath(path, line);
          final arrow = Path()
            ..moveTo(tipX - 4, arriveY - 3.5)
            ..lineTo(tipX + 1, arriveY)
            ..lineTo(tipX - 4, arriveY + 3.5);
          canvas.drawPath(arrow, line);
      }
    }
  }

  @override
  bool shouldRepaint(TimelineJumpPainter oldDelegate) =>
      oldDelegate.gutterWidth != gutterWidth ||
      oldDelegate.exitY != exitY ||
      oldDelegate.arriveY != arriveY ||
      !_sameSegments(oldDelegate.segments, segments);

  static bool _sameSegments(
    List<TimelineJumpSegment> a,
    List<TimelineJumpSegment> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Pill compacta de llegada de un salto: el label de la rama sobre fill
/// sólido, para taparse encima del conector espinal sin transparencias.
/// Más chica que un `AppPill` a propósito: vive en la franja de 24 px
/// entre filas y es señal ambiental, no estado.
class TimelineJumpBadge extends StatelessWidget {
  const TimelineJumpBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp2),
      decoration: BoxDecoration(
        color: AppTokens.surface3,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTokens.fontSans,
          fontSize: AppTokens.captionSize,
          height: AppTokens.captionLineHeight / AppTokens.captionSize,
          fontWeight: AppTokens.captionWeight,
          color: AppTokens.text2,
        ),
      ),
    );
  }
}

/// Franja de llegada de saltos: las pills etiquetadas de las ramas que
/// desembocan en la fila de abajo, ancladas sobre la espina (su fill la
/// tapa) justo donde la flecha del conector remata.
class TimelineArrivalStrip extends StatelessWidget {
  const TimelineArrivalStrip({super.key, required this.labels});

  /// Alto fijo de la franja; el painter de saltos remata a su mitad.
  static const double height = 24.0;

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: <Widget>[
          const TimelineSpineBar(),
          Positioned.fill(
            left: AppTimelineRow.railWidth / 2 - 6,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: AppTokens.sp1,
                children: <Widget>[
                  for (final label in labels) TimelineJumpBadge(label: label),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
