import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import 'app_timeline_insert.dart';
import 'app_timeline_jump.dart';
import 'app_timeline_row.dart';

/// Lista de secuencia del design system: filas indexadas unidas por una
/// espina vertical, con reorder por arrastre VALIDADO antes del drop,
/// inserción posicional entre filas y saltos de rama dibujados en el
/// margen izquierdo. Es el idioma visual de "la estructura se ve, no se
/// lee": índice + conector + saltos son del kit; cada fila ([itemBuilder],
/// normalmente un `AppTimelineRow`) es opaca.
///
/// - **Reorder**: con [onReorder] y ≥2 items envuelve un
///   `ReorderableListView.builder` (handles propios de las filas, proxy
///   elevado, haptic al asentar). [canReorder] corre ANTES de aplicar el
///   drop: si lo veta, el drop no se reporta y la fila revierte sola a su
///   posición — el consumidor decide ahí mismo cómo avisar. Ambos callbacks
///   reciben índices ya ajustados (el destino ya descuenta la fila movida).
/// - **Inserción**: [onInsertAt] monta una zona de tap discreta ENTRE
///   filas (glifo "+" quieto que se enciende al hover) y un inserter
///   SIEMPRE visible al final. `index` es la posición que ocupará lo
///   insertado. No hay zona antes de la primera fila: el timeline lee
///   "entre" y "al final"; llegar a la posición 0 es un reorder.
/// - **Saltos**: cada [TimelineJump] dibuja su conector en el margen (un
///   carril propio cuando se solapan — ver [timelineJumpLanes]) y remata
///   en la fila destino con una pill etiquetada.
/// - [header] y [footer] viven DENTRO del mismo scroll que las filas.
///
/// Con <2 items o sin [onReorder] no se paga el costo del scroll de
/// reorder: lista simple con la misma anatomía.
class AppStepTimeline extends StatelessWidget {
  const AppStepTimeline({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemKey,
    this.onReorder,
    this.canReorder,
    this.onInsertAt,
    this.insertEndLabel = 'Agregar paso',
    this.insertEndKey,
    this.jumps = const <TimelineJump>[],
    this.header,
    this.footer,
    this.padding,
    this.controller,
  });

  final int itemCount;

  /// Construye la fila [index]. Normalmente un `AppTimelineRow`; el kit no
  /// impone el tipo.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Identidad ESTABLE del item [index] (no del slot): el reorder la exige
  /// y el consumidor puede usar `GlobalKey`s propias para localizar filas
  /// (scroll-to del recién insertado).
  final Key Function(int index) itemKey;

  /// Aplica el drop: mover la fila [from] a la posición [to] (ajustada).
  final void Function(int from, int to)? onReorder;

  /// Veto previo al drop. False ⇒ [onReorder] no corre y la fila revierte.
  final bool Function(int from, int to)? canReorder;

  /// Inserción posicional: lo insertado ocupará la posición [index].
  final void Function(int index)? onInsertAt;

  /// Label del inserter siempre visible al final del timeline.
  final String insertEndLabel;

  /// Key del inserter final, para que el consumidor lo nombre en su
  /// superficie (default: `app_step_timeline.insert.end`).
  final Key? insertEndKey;

  /// Saltos de rama a dibujar. Solo hacia adelante (`from < to`).
  final List<TimelineJump> jumps;

  final Widget? header;
  final Widget? footer;
  final EdgeInsets? padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final lanes = timelineJumpLanes(jumps);
    var laneCount = 0;
    for (final lane in lanes) {
      if (lane + 1 > laneCount) laneCount = lane + 1;
    }
    final gutterWidth = timelineJumpGutterWidth(laneCount);

    final reorder = onReorder;
    final reorderable = reorder != null && itemCount >= 2;
    final footerBlock = _footerBlock(gutterWidth);

    if (!reorderable) {
      return ListView(
        controller: controller,
        padding: padding,
        children: <Widget>[
          ?header,
          for (var i = 0; i < itemCount; i++)
            _buildItem(context, i, gutterWidth, lanes),
          ?footerBlock,
        ],
      );
    }

    return ReorderableListView.builder(
      scrollController: controller,
      padding: padding,
      header: header,
      footer: footerBlock,
      buildDefaultDragHandles: false,
      proxyDecorator: _proxyDecorator,
      itemCount: itemCount,
      itemBuilder: (ctx, i) => _buildItem(ctx, i, gutterWidth, lanes),
      onReorderItem: (from, to) {
        if (from == to) return;
        // La validación corre ANTES de reportar el drop: un veto deja la
        // lista intacta y la fila animada de regreso — el invariante se
        // previene en la UI, sin round-trip.
        if (canReorder != null && !canReorder!(from, to)) return;
        HapticFeedback.selectionClick();
        reorder(from, to);
      },
    );
  }

  /// Item completo de la fila [i]: franja de llegadas + fila del consumidor
  /// + franja inferior (espaciado con espina y, si aplica, zona de
  /// inserción), todo desplazado por el margen de saltos y con las
  /// rebanadas de conector pintadas detrás.
  Widget _buildItem(
    BuildContext context,
    int i,
    double gutterWidth,
    List<int> lanes,
  ) {
    final arrivals = <String>[
      for (final j in jumps)
        if (j.to == i) j.label,
    ];
    final segments = timelineJumpSegmentsAt(i, jumps, lanes);
    final stripHeight = arrivals.isEmpty ? 0.0 : TimelineArrivalStrip.height;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (arrivals.isNotEmpty) TimelineArrivalStrip(labels: arrivals),
        itemBuilder(context, i),
        if (i < itemCount - 1)
          TimelineRowGap(
            insertIndex: onInsertAt == null ? null : i + 1,
            onInsertAt: onInsertAt,
          ),
      ],
    );
    content = Padding(
      padding: EdgeInsets.only(left: gutterWidth),
      child: content,
    );
    if (segments.isNotEmpty) {
      content = CustomPaint(
        painter: TimelineJumpPainter(
          segments: segments,
          gutterWidth: gutterWidth,
          exitY: stripHeight + AppTimelineRow.bulletCenterY,
          arriveY: TimelineArrivalStrip.height / 2,
        ),
        child: content,
      );
    }
    return KeyedSubtree(key: itemKey(i), child: content);
  }

  /// Footer del scroll: el inserter final (si hay inserción) + el footer
  /// del consumidor.
  Widget? _footerBlock(double gutterWidth) {
    final insert = onInsertAt;
    final f = footer;
    if (insert == null && f == null) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (insert != null)
          Padding(
            padding: EdgeInsets.only(
              // Alineado con el contenido de las filas (margen + riel).
              left: gutterWidth + AppTimelineRow.railWidth + AppTokens.sp2,
              top: AppTokens.sp3,
            ),
            child: TimelineEndInserter(
              key: insertEndKey ?? const Key('app_step_timeline.insert.end'),
              label: insertEndLabel,
              onTap: () => insert(itemCount),
            ),
          ),
        ?f,
      ],
    );
  }

  /// Proxy del item arrastrado: se despega con sombra y un scale sutil —
  /// la fila "en la mano" se distingue sin cambiar de identidad visual.
  static Widget _proxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, kid) {
        final t = Curves.easeOut.transform(animation.value);
        return Transform.scale(
          scale: 1 + 0.02 * t,
          child: Material(
            color: Colors.transparent,
            elevation: 6 * t,
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            child: kid,
          ),
        );
      },
      child: child,
    );
  }
}
