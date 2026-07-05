import 'package:flutter/material.dart';

import '../tokens.dart';

/// Fila de un `AppStepTimeline`: índice + conector vertical (la espina que
/// une las filas) a la izquierda, [badge] opcional encima y el [child] al
/// frente. El child es OPACO para el kit — el idioma visual del timeline
/// es el índice y el conector; qué se pinta en cada fila lo decide el
/// consumidor.
///
/// La fila es usable suelta (dibuja su propia espina, recortable por los
/// extremos con [spineAbove]/[spineBelow]); dentro del timeline, la
/// continuidad de la espina a través de las franjas entre filas la
/// completa el propio timeline con las mismas constantes de geometría.
class AppTimelineRow extends StatefulWidget {
  const AppTimelineRow({
    super.key,
    required this.index,
    required this.child,
    this.badge,
    this.spineAbove = true,
    this.spineBelow = true,
    this.dragIndex,
    this.dragHandleKey,
    this.highlighted = false,
  });

  /// Ancho del riel del índice (bullet + espina). Compartido con el
  /// timeline para alinear las franjas entre filas y el margen de saltos.
  static const double railWidth = 36.0;

  /// Y del centro del bullet respecto del tope de la fila: alineado con
  /// la primera línea de un child típico (padding sp3 + media línea).
  static const double bulletCenterY = 22.0;

  /// Grosor y color de la espina — mismos valores en el timeline para que
  /// los tramos pintados por ambos empalmen sin costura.
  static const double spineWidth = 2.0;
  static const Color spineColor = AppTokens.divider;

  static const double _bulletRadius = 12.0;

  /// Posición 0-based de la fila; el bullet pinta `index + 1`.
  final int index;

  /// Contenido de la fila. Opaco para el kit.
  final Widget child;

  /// Slot encima del child, junto al riel: pill de rama u otra señal
  /// ambiental que el consumidor quiera anclar a la fila.
  final Widget? badge;

  /// Si la espina continúa hacia arriba (false en la primera fila).
  final bool spineAbove;

  /// Si la espina continúa hacia abajo (false en la última fila).
  final bool spineBelow;

  /// Índice para el `ReorderableDragStartListener` del handle. Null ⇒ la
  /// fila no es arrastrable y no monta handle.
  final int? dragIndex;

  /// Key del ícono del handle, para que el consumidor lo identifique en
  /// sus tests sin acoplar el kit a sus nombres.
  final Key? dragHandleKey;

  /// True anuncia la fila recién llegada: un glow one-shot que se apaga
  /// solo. Re-anima solo en la transición false→true — rebuilds con true
  /// sostenido no lo reinician.
  final bool highlighted;

  @override
  State<AppTimelineRow> createState() => _AppTimelineRowState();
}

class _AppTimelineRowState extends State<AppTimelineRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    // Se crea aquí (no lazy): un `late` tocado por primera vez en dispose
    // buscaría el TickerMode con el elemento ya desactivado.
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.highlighted) _glow.forward();
  }

  @override
  void didUpdateWidget(AppTimelineRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlighted && !oldWidget.highlighted) {
      _glow.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final dragIdx = widget.dragIndex;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (badge != null) ...<Widget>[
          badge,
          const SizedBox(height: AppTokens.sp1),
        ],
        widget.child,
      ],
    );
    if (widget.highlighted) {
      content = _HighlightGlow(animation: _glow, child: content);
    }

    // IntrinsicHeight estira el riel a la altura real del child para que
    // la espina lo recorra completo. Costo aceptable: filas de lista, no
    // grids profundos.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: AppTimelineRow.railWidth,
            child: CustomPaint(
              painter: _RailPainter(
                spineAbove: widget.spineAbove,
                spineBelow: widget.spineBelow,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top:
                        AppTimelineRow.bulletCenterY -
                        AppTimelineRow._bulletRadius,
                  ),
                  child: _IndexBullet(number: widget.index + 1),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTokens.sp2),
          Expanded(child: content),
          if (dragIdx != null)
            ReorderableDragStartListener(
              index: dragIdx,
              // 48x48: área de agarre táctil mínima (el ícono solo mide 24
              // y es demasiado fino para el pulgar). ExcludeSemantics
              // colapsa el nodo del ícono en la etiqueta de acción.
              child: Semantics(
                label: 'Mover paso',
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.drag_handle,
                      key: widget.dragHandleKey,
                      color: AppTokens.text2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bullet del índice: círculo sólido que además tapa la espina detrás.
class _IndexBullet extends StatelessWidget {
  const _IndexBullet({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('app_timeline_row.bullet'),
      width: AppTimelineRow._bulletRadius * 2,
      height: AppTimelineRow._bulletRadius * 2,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppTokens.surface2,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          fontFamily: AppTokens.fontSans,
          fontSize: AppTokens.captionSize,
          fontWeight: AppTokens.captionWeight,
          color: AppTokens.text2,
        ),
      ),
    );
  }
}

/// Espina vertical del riel: del tope al bullet y del bullet al fondo,
/// recortable por extremo. El bullet se pinta encima como widget.
class _RailPainter extends CustomPainter {
  const _RailPainter({required this.spineAbove, required this.spineBelow});

  final bool spineAbove;
  final bool spineBelow;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTimelineRow.spineColor
      ..strokeWidth = AppTimelineRow.spineWidth;
    final x = size.width / 2;
    if (spineAbove) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, AppTimelineRow.bulletCenterY),
        paint,
      );
    }
    if (spineBelow) {
      canvas.drawLine(
        Offset(x, AppTimelineRow.bulletCenterY),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RailPainter oldDelegate) =>
      oldDelegate.spineAbove != spineAbove ||
      oldDelegate.spineBelow != spineBelow;
}

/// Barra vertical que continúa la espina del riel a través de las franjas
/// entre filas del timeline (llegadas de saltos, zona de inserción):
/// misma geometría que el painter del riel para empalmar sin costura.
class TimelineSpineBar extends StatelessWidget {
  const TimelineSpineBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: AppTimelineRow.railWidth / 2 - AppTimelineRow.spineWidth / 2,
      top: 0,
      bottom: 0,
      child: Container(
        width: AppTimelineRow.spineWidth,
        color: AppTimelineRow.spineColor,
      ),
    );
  }
}

/// Glow one-shot del highlight: halo cálido que se enciende rápido y se
/// desvanece — anuncia la fila recién creada sin exigir interacción.
class _HighlightGlow extends StatelessWidget {
  const _HighlightGlow({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, kid) {
        final t = animation.value;
        // Sube a pleno en el primer quinto y se apaga el resto del ciclo.
        final strength = t < 0.2 ? t / 0.2 : 1 - ((t - 0.2) / 0.8);
        return DecoratedBox(
          key: const Key('app_timeline_row.highlight'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppTokens.primaryGlow.withValues(
                  alpha: AppTokens.primaryGlow.a * strength,
                ),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: kid,
        );
      },
      child: child,
    );
  }
}
