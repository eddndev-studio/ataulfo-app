import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/tokens.dart';
import '../design/widgets/app_button.dart';
import '../design/widgets/app_thread_event_card.dart';
import 'trace_node.dart';

/// Timeline vertical de una traza estilo Claude: un carril con un nodo por
/// paso (ícono + título + cuerpo opcional), colapsable a una línea-resumen con
/// chevron. Feature-agnóstico —recibe nodos, resumen y flags, sin conocer al
/// asistente, al entrenador ni al hilo real—; los cuerpos ricos (razonamiento
/// plegable, tarjetas de tool) los inyecta el llamador vía [bodyBuilder].
///
/// - Colapsado (default histórico): solo el resumen; tocarlo expande.
/// - Expandido (default vivo): el carril completo. El pulso late SOLO en el
///   último nodo de una traza viva y respeta el opt-out de motion.
/// - Con [onStop] muestra «Detener»: al tocarlo colapsa al [stoppedSummary]
///   honesto y avisa (el cancel es del cliente; el servidor pudo continuar).
class TraceTimeline extends StatefulWidget {
  const TraceTimeline({
    super.key,
    required this.nodes,
    required this.summary,
    this.bodyBuilder,
    this.initiallyExpanded = false,
    this.pulseLast = false,
    this.onStop,
    this.stopButtonKey,
    this.stoppedSummary = '',
    this.stopped = false,
    this.collapsedLeading,
    this.stretch = false,
  });

  final List<TraceNode> nodes;
  final String summary;

  /// Modo hilo de mensajes: la tarjeta se pega al área de mensaje (izquierda) y
  /// llena el ancho de la columna en AMBOS estados —colapsada y expandida— para
  /// que abrir el proceso no recalcule el ancho ni la deje flotando al centro.
  /// Apagado (default) conserva la tarjeta centrada que abraza su contenido (el
  /// registro de una corrida en el ai-log, el monitor, la mini-traza del hilo
  /// real).
  final bool stretch;

  /// Widget que sustituye al ícono del renglón COLAPSADO (p. ej. el latido de
  /// la mini-traza viva del hilo). `null` ⇒ el ícono del primer nodo.
  final Widget? collapsedLeading;

  /// Cuerpo rico del nodo `i` (o `null`): las tarjetas/razonamiento del
  /// llamador. En vivo se deja nulo (los nodos vivos son solo etiquetas).
  final Widget? Function(BuildContext, int)? bodyBuilder;

  final bool initiallyExpanded;

  /// Late el último nodo (traza viva en vuelo). Se apaga con motion off.
  final bool pulseLast;

  /// Presente ⇒ una traza viva detenible: muestra «Detener».
  final VoidCallback? onStop;
  final Key? stopButtonKey;
  final String stoppedSummary;

  /// Detención impuesta desde afuera (el dueño del estado supo del cancel):
  /// pinta el [stoppedSummary] aunque este widget se haya reconstruido y su
  /// estado interno no haya visto el tap.
  final bool stopped;

  @override
  State<TraceTimeline> createState() => _TraceTimelineState();
}

class _TraceTimelineState extends State<TraceTimeline> {
  /// Tope de ancho del contenido de la tarjeta. Acota el contenido largo y —en
  /// modo hilo— iguala colapsada y expandida (mismo ancho al abrir). Deliberado
  /// que NO sea la columna entera: a lo ancho, el cuerpo rico de un nodo puede
  /// desbordar el IntrinsicHeight del carril.
  static const double _threadMaxWidth = 520;

  late bool _expanded = widget.initiallyExpanded;
  bool _stopped = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  void _stop() {
    setState(() => _stopped = true);
    widget.onStop?.call();
  }

  IconData get _leadingIcon =>
      widget.nodes.isNotEmpty ? widget.nodes.first.icon : Icons.bolt;

  bool get _isError => widget.nodes.any((n) => n.isError);

  @override
  Widget build(BuildContext context) {
    // El plegado/expandido anima el alto (y, sin stretch, el ancho) en vez de
    // saltar. Con motion off la duración colapsa a cero y el cambio es directo.
    return AnimatedSize(
      duration: AppMotion.durationOf(
        context,
        const Duration(milliseconds: 200),
      ),
      curve: Curves.easeOutCubic,
      alignment: widget.stretch ? Alignment.topLeft : Alignment.topCenter,
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    if (_stopped || widget.stopped) {
      // Detenida: SIN el leading vivo — un latido sobre el copy de detención
      // mentiría actividad.
      return _collapsed(
        label: widget.stoppedSummary,
        icon: Icons.stop_circle_outlined,
        tappable: false,
        error: false,
      );
    }
    if (!_expanded) {
      return _collapsed(
        label: widget.summary,
        icon: _leadingIcon,
        tappable: true,
        error: _isError,
        leading: widget.collapsedLeading,
      );
    }
    return _expandedCard(context);
  }

  /// El «Detener» acompaña a la traza viva también COLAPSADA: plegar el carril
  /// no puede esconder el único control de cancelación del turno.
  Widget _collapsed({
    required String label,
    required IconData icon,
    required bool tappable,
    required bool error,
    Widget? leading,
  }) => AppThreadEventCard(
    error: error,
    onTap: tappable ? _toggle : null,
    fill: widget.stretch,
    // En hilo, MISMO tope que expandida (520): así colapsada y expandida miden
    // igual —sin recálculo al abrir— y llena la columna hasta ese tope.
    maxWidth: widget.stretch ? _threadMaxWidth : null,
    alignment: widget.stretch ? Alignment.centerLeft : Alignment.center,
    child: widget.onStop == null || _stopped || widget.stopped
        ? AppThreadEventHeader(
            icon: icon,
            label: label,
            error: error,
            showChevron: tappable,
            leading: leading,
          )
        : Row(
            children: <Widget>[
              Expanded(
                child: AppThreadEventHeader(
                  icon: icon,
                  label: label,
                  error: error,
                  showChevron: tappable,
                  leading: leading,
                ),
              ),
              AppButton.text(
                key: widget.stopButtonKey,
                label: 'Detener',
                icon: Icons.stop_rounded,
                onPressed: _stop,
              ),
            ],
          ),
  );

  Widget _expandedCard(BuildContext context) {
    final motion = AppMotion.enabledOf(context);
    final last = widget.nodes.length - 1;
    return AppThreadEventCard(
      expanded: true,
      fill: true,
      // Mismo tope (520) en hilo y fuera: en hilo iguala a la colapsada (sin
      // salto de ancho al abrir) y llena la columna hasta ese tope, pegada a la
      // izquierda; fuera de hilo acota el contenido largo y queda centrada. NO
      // llenar la columna entera: a lo ancho, el cuerpo rico de un nodo puede
      // desbordar el IntrinsicHeight del carril (mismatch intrínseco-vs-real).
      maxWidth: _threadMaxWidth,
      alignment: widget.stretch ? Alignment.centerLeft : Alignment.center,
      error: _isError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: AppThreadEventHeader(
              icon: _leadingIcon,
              label: widget.summary,
              error: _isError,
              showChevron: true,
              expanded: true,
            ),
          ),
          const SizedBox(height: AppTokens.sp3),
          for (int i = 0; i < widget.nodes.length; i++)
            _TraceNodeRow(
              node: widget.nodes[i],
              isFirst: i == 0,
              isLast: i == last,
              pulse: widget.pulseLast && i == last && motion,
              body: widget.bodyBuilder?.call(context, i),
            ),
          if (widget.onStop != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp1),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton.text(
                key: widget.stopButtonKey,
                label: 'Detener',
                icon: Icons.stop_rounded,
                onPressed: _stop,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Una fila del carril: rail (línea hairline + punto) + ícono, título y cuerpo.
class _TraceNodeRow extends StatelessWidget {
  const _TraceNodeRow({
    required this.node,
    required this.isFirst,
    required this.isLast,
    required this.pulse,
    this.body,
  });

  final TraceNode node;
  final bool isFirst;
  final bool isLast;
  final bool pulse;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = node.kind == TraceNodeKind.masN;
    final accent = node.isError
        ? AppTokens.danger
        : (muted ? AppTokens.text2 : AppTokens.primary);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Rail(isFirst: isFirst, isLast: isLast, pulse: pulse, color: accent),
          const SizedBox(width: AppTokens.sp2),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppTokens.sp3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(node.icon, size: 16, color: accent),
                      const SizedBox(width: AppTokens.sp2),
                      Expanded(
                        child: Text(
                          node.titulo,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: node.isError
                                ? AppTokens.danger
                                : (muted ? AppTokens.text2 : AppTokens.text1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (body != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppTokens.sp2,
                        left: 24,
                      ),
                      child: body,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El carril de un nodo: un punto alineado con el ícono y los segmentos de
/// línea 2px que lo unen con el nodo previo/siguiente (transparentes en los
/// extremos). El punto del nodo activo (vivo) late.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.isFirst,
    required this.isLast,
    required this.pulse,
    required this.color,
  });

  final bool isFirst;
  final bool isLast;
  final bool pulse;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // Tramo por encima del punto: lo alinea con el centro del ícono.
          SizedBox(
            height: 8,
            child: Center(
              child: Container(
                width: 2,
                color: isFirst ? Colors.transparent : AppTokens.divider,
              ),
            ),
          ),
          pulse ? _PulsingDot(color: color) : _Dot(color: color),
          Expanded(
            child: Center(
              child: Container(
                width: 2,
                color: isLast ? Colors.transparent : AppTokens.divider,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Punto del nodo activo con un halo que late. Solo se monta con motion on: su
/// mera presencia (Key `trace.pulse`) es la señal de que hay pulso.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('trace.pulse'),
      width: 8,
      height: 8,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
        child: Container(
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
