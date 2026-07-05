import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_expandable_panel.dart';
import '../../../media/domain/repositories/device_gallery_port.dart';
import '../bloc/attach_panel_cubit.dart';
import 'attach_gallery_picker.dart';
import 'attach_menu_row.dart';

/// Medidas del panel de adjuntar para un estado dado: cuánto reserva bajo el
/// composer (el composer sube exactamente esto) y —si es expandible— las
/// fracciones del alto disponible que consume la hoja.
///
/// El panel es EXPANDIBLE sólo con carrete y en la vista de destinos: ahí crece
/// por arrastre para mostrar la grilla del carrete. En cualquier otra forma
/// (sin carrete, o la sub-vista de cámara) es una superficie FIJA y compacta.
/// La misma medida la usan la página (para reservar espacio) y el panel (para
/// dimensionarse): una sola fuente de verdad evita que se desincronicen.
class AttachPanelMetrics {
  const AttachPanelMetrics({
    required this.expandable,
    required this.reservedHeight,
    required this.initialFraction,
    required this.minFraction,
    required this.maxFraction,
  });

  /// Deriva las medidas del estado del panel y el alto disponible.
  factory AttachPanelMetrics.of(
    AttachPanelState state, {
    required double available,
    required double bottomInset,
  }) {
    final expandable =
        state.showGallery && state.view == AttachPanelView.destinations;
    if (!expandable) {
      return AttachPanelMetrics(
        expandable: false,
        reservedHeight: _collapsedHeight + bottomInset,
        initialFraction: 0,
        minFraction: 0,
        maxFraction: 0,
      );
    }
    final base = math.min(available * 0.45, _maxExpandableBase);
    final initial = available > 0 ? base / available : 0.45;
    return AttachPanelMetrics(
      expandable: true,
      reservedHeight: base,
      // El mínimo mantiene la proporción del gesto original (0.30/0.45): cruzar
      // ~un tercio del alto base auto-descarta el panel.
      initialFraction: initial,
      minFraction: initial * (0.30 / 0.45),
      maxFraction: 0.95,
    );
  }

  /// Alto de la forma fija (fila de destinos sin carrete o sub-vista cámara):
  /// cabe una fila de tiles con holgura.
  static const double _collapsedHeight = 152;

  /// Tope del alto base expandible en pantallas altas (desktop): sin él, 0.45
  /// del alto se comería la vista.
  static const double _maxExpandableBase = 460;

  final bool expandable;

  /// Alto reservado bajo el composer en la altura base del panel.
  final double reservedHeight;

  /// Fracciones del alto disponible para la hoja expandible (ignoradas en la
  /// forma fija).
  final double initialFraction;
  final double minFraction;
  final double maxFraction;
}

/// Ancla el panel de adjuntar inline al fondo del contenido del hilo. Compone
/// la columna [children] (lista, banners, composer…) y, con el panel abierto,
/// reserva su alto base bajo el composer —éste sube, como con el teclado (I2)—
/// y lo superpone; al expandirse el panel crece sobre el contenido (I3). Con el
/// panel abierto, el back del sistema lo CIERRA en vez de navegar (I6).
///
/// La estructura es ESTABLE entre panel abierto/cerrado (mismo `Stack` +
/// `Column`, [children] en el mismo índice): abrir el panel no reconstruye el
/// composer ni pierde su bandeja/borrador. Es el contenedor CANÓNICO del panel:
/// la página y los tests de invariantes lo consumen tal cual, así una deriva del
/// layout rompe ambos por igual.
class AttachPanelScaffold extends StatelessWidget {
  const AttachPanelScaffold({super.key, required this.children});

  /// Filas de la columna del hilo, de arriba a abajo (la lista `Expanded`,
  /// banners y el composer). La reserva del panel se añade al final.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final panel = context.watch<AttachPanelCubit>().state;
    return PopScope<Object?>(
      canPop: panel == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.read<AttachPanelCubit>().dismiss();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = panel == null
              ? null
              : AttachPanelMetrics.of(
                  panel,
                  available: constraints.maxHeight,
                  bottomInset: MediaQuery.viewPaddingOf(context).bottom,
                );
          return Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  ...children,
                  // Reserva el alto base del panel bajo el composer: éste sube
                  // exactamente eso, sin dejar hueco.
                  if (metrics != null) SizedBox(height: metrics.reservedHeight),
                ],
              ),
              // El panel se pinta encima: en su base cae en el hueco reservado
              // bajo el composer; al expandirse crece sobre el hilo.
              if (metrics != null)
                Positioned.fill(child: AttachPanel(metrics: metrics)),
            ],
          );
        },
      ),
    );
  }
}

/// El panel de adjuntar del hilo (estilo WhatsApp), anclado al fondo del layout
/// de la página —no es ruta—. Se pinta cuando el [AttachPanelCubit] está
/// abierto y se dimensiona con [metrics]. Dos formas:
///
/// - **Expandible** (con carrete, vista de destinos): fila de íconos fija arriba
///   + grilla del carrete que crece al arrastrar ([AppExpandablePanel]).
/// - **Fija** (sin carrete, o la sub-vista de cámara): superficie compacta
///   anclada abajo con la fila de destinos, o la elección Foto/Video.
///
/// Cada destino habla con el cubit; el composer (que escucha las intenciones)
/// ejecuta el flujo con sus dependencias. Elegir un destino cierra el panel;
/// Cámara y Galería NO cierran (cambian de vista / expanden).
class AttachPanel extends StatelessWidget {
  const AttachPanel({super.key, required this.metrics});

  final AttachPanelMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttachPanelCubit, AttachPanelState?>(
      builder: (context, state) {
        if (state == null) return const SizedBox.shrink();
        final cubit = context.read<AttachPanelCubit>();
        if (state.view == AttachPanelView.camera) {
          return _fixedShell(context, child: _CameraView(cubit: cubit));
        }
        if (metrics.expandable) {
          return _expandable(context, state, cubit);
        }
        return _fixedShell(
          context,
          child: AttachMenuRow(
            onDocument: cubit.chooseDocument,
            onMedia: cubit.chooseMedia,
            onCamera: state.showCamera ? cubit.showCameraView : null,
          ),
        );
      },
    );
  }

  /// La forma expandible: la hoja del kit con la fila de destinos fija arriba y
  /// la grilla del carrete como cuerpo scrolleable. La Galería expande al
  /// máximo; cruzar el mínimo cierra el panel.
  Widget _expandable(
    BuildContext context,
    AttachPanelState state,
    AttachPanelCubit cubit,
  ) {
    final gallery = context.read<DeviceGalleryPort>();
    return AppExpandablePanel(
      handleKey: const Key('attach_panel.handle'),
      initialSize: metrics.initialFraction,
      minSize: metrics.minFraction,
      maxSize: metrics.maxFraction,
      onDismissed: cubit.dismiss,
      headerBuilder: (context, expand) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.sp6,
          0,
          AppTokens.sp6,
          AppTokens.sp3,
        ),
        child: AttachMenuRow(
          onDocument: cubit.chooseDocument,
          onMedia: cubit.chooseMedia,
          onCamera: state.showCamera ? cubit.showCameraView : null,
          onGallery: expand,
        ),
      ),
      builder: (context, scrollController) => AttachGalleryPicker(
        gallery: gallery,
        scrollController: scrollController,
        onConfirm: cubit.confirmGallery,
      ),
    );
  }

  /// Cascarón de la forma fija: superficie `surface1` anclada abajo, del alto
  /// reservado, que despeja la gesture-nav con su padding inferior.
  Widget _fixedShell(BuildContext context, {required Widget child}) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: metrics.reservedHeight,
        child: Container(
          key: const Key('attach_panel.fixed'),
          decoration: const BoxDecoration(
            color: AppTokens.surface1,
            border: Border(top: BorderSide(color: AppTokens.divider)),
          ),
          padding: EdgeInsets.fromLTRB(
            AppTokens.sp4,
            AppTokens.sp4,
            AppTokens.sp4,
            AppTokens.sp4 + context.safeBottomInset,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// La sub-vista de cámara dentro del panel (swap de contenido, NUNCA una ruta):
/// una sola fila —volver + los tiles Foto/Video— con el MISMO vocabulario
/// visual de la fila de destinos. Compacta para caber en la altura fija.
class _CameraView extends StatelessWidget {
  const _CameraView({required this.cubit});

  final AttachPanelCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          key: const Key('attach_panel.camera_back'),
          tooltip: 'Volver',
          color: AppTokens.text2,
          onPressed: cubit.showDestinations,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: AppTokens.sp2),
        AttachTile(
          key: const Key('attach_menu.camera.photo'),
          icon: Icons.photo_camera_outlined,
          label: 'Foto',
          onTap: cubit.choosePhoto,
        ),
        const SizedBox(width: AppTokens.sp4),
        AttachTile(
          key: const Key('attach_menu.camera.video'),
          icon: Icons.videocam_outlined,
          label: 'Video',
          onTap: cubit.chooseVideo,
        ),
      ],
    );
  }
}
