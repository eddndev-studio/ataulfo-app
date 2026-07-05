import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_section_link.dart';
import '../../../../core/design/widgets/app_swatch_icon.dart';
import '../../domain/entities/wa_label.dart';
import '../../domain/failures/wa_labels_failure.dart';
import '../bloc/wa_labels_bloc.dart';
import '../widgets/wa_label_edit_sheet.dart';
import '../widgets/wa_label_palette.dart';

/// Catálogo de etiquetas WhatsApp del bot (S21). Consume el `WaLabelsBloc` del
/// scope (la ruta `/bots/:id/wa-labels` lo cabla con el botId). Posee su propio
/// Scaffold porque la sección tiene un FAB ligado al bloc (crear) y sheets
/// modales (crear/editar) — a diferencia de las sub-secciones de solo lectura.
///
/// Lee el espejo y pinta solo las etiquetas activas (filtra tombstones); el
/// swatch resuelve el índice de paleta de WhatsApp. Se actualiza en vivo por SSE
/// `label.wa.*` sin recargar. Tocar una etiqueta abre el sheet de edición; el
/// FAB abre el de creación.
class WaLabelsPage extends StatelessWidget {
  const WaLabelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El acceso a los vínculos vive en el CUERPO como card launcher (un
      // icono de AppBar era una affordance invisible para la feature que
      // convierte etiquetas en automatizaciones).
      appBar: AppBar(title: const Text('Etiquetas de WhatsApp')),
      body: BlocBuilder<WaLabelsBloc, WaLabelsState>(
        builder: (context, state) => switch (state) {
          WaLabelsLoading() => const _LoadingView(),
          WaLabelsLoaded(labels: final labels) ||
          WaLabelsMutating(labels: final labels) ||
          WaLabelsMutationFailed(
            labels: final labels,
          ) => _LoadedView(labels: labels),
          WaLabelsFailed(failure: final f) => _FailedView(failure: f),
        },
      ),
      floatingActionButton: BlocBuilder<WaLabelsBloc, WaLabelsState>(
        builder: (context, state) {
          // El FAB solo aparece cuando hay un catálogo cargado (crear necesita
          // un snapshot sobre el que aplicar el alta optimista).
          final canCreate =
              state is WaLabelsLoaded ||
              state is WaLabelsMutating ||
              state is WaLabelsMutationFailed;
          if (!canCreate) return const SizedBox.shrink();
          return FloatingActionButton(
            key: const Key('wa_labels.create'),
            onPressed: () => WaLabelEditSheet.openCreate(context),
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.labels});

  final List<WaLabel> labels;

  @override
  Widget build(BuildContext context) {
    // Solo activas: el espejo conserva tombstones (deleted:true) pero la UI no
    // los pinta como etiquetas vivas.
    final active = labels.where((l) => !l.deleted).toList(growable: false);
    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<WaLabelsBloc>();
        bloc.add(const WaLabelsRefreshRequested());
        // `orElse` evita un StateError async si el bloc se cierra (el operador
        // navega fuera) mientras el refresh sigue en vuelo: el stream completa
        // sin emitir el estado esperado y `firstWhere` lanzaría sin él.
        await bloc.stream.firstWhere(
          (s) =>
              (s is WaLabelsLoaded && !s.isRefreshing) || s is WaLabelsFailed,
          orElse: () => bloc.state,
        );
      },
      child: active.isEmpty
          ? const _EmptyView()
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppTokens.sp4,
                AppTokens.sp4,
                AppTokens.sp4,
                // fabClearance: la última fila debe poder quedar por encima
                // del FAB de crear que flota sobre esta página.
                AppTokens.fabClearance + context.safeBottomInset,
              ),
              children: <Widget>[
                const _MappingsLauncher(),
                const SizedBox(height: AppTokens.sp5),
                _WaLabelsCard(labels: active),
              ],
            ),
    );
  }
}

/// Catálogo como UNA card que apila las etiquetas separadas por divider
/// hairline (idioma de los hubs y de ajustes), en lugar de una card suelta por
/// item. La identidad de cada fila la lleva su glifo tintado.
class _WaLabelsCard extends StatelessWidget {
  const _WaLabelsCard({required this.labels});

  final List<WaLabel> labels;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      if (i > 0) {
        rows.add(
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
        );
      }
      rows.add(_WaLabelTile(label: labels[i]));
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}

/// Card launcher hacia el mapeo WA ↔ Label interno: LA acción que convierte
/// "etiqueté un chat en WhatsApp" en una automatización merece una affordance
/// visible, no un icono de AppBar. Conserva su card propia porque es un
/// destino de navegación, no un item del catálogo: apilarlo dentro de la card
/// de etiquetas lo camuflaría como una etiqueta más.
class _MappingsLauncher extends StatelessWidget {
  const _MappingsLauncher();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: AppSectionLink(
        rowKey: const Key('wa_labels.mappings'),
        icon: Icons.link,
        title: 'Vínculos con etiquetas internas',
        caption: 'Qué automatización dispara cada etiqueta',
        onTap: () {
          final botId = context.read<WaLabelsBloc>().botId;
          context.push('/bots/$botId/wa-label-mappings');
        },
      ),
    );
  }
}

/// Fila de una etiqueta dentro de la card del catálogo: glifo tintado + nombre
/// + chevron. Toda la fila es tap-target hacia el sheet de edición; el InkWell
/// propio da el ripple (la card contenedora no es tappable).
class _WaLabelTile extends StatelessWidget {
  const _WaLabelTile({required this.label});

  final WaLabel label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: Key('wa_labels.tile.${label.waLabelId}'),
      onTap: () => WaLabelEditSheet.openEdit(context, label),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
        child: Row(
          children: <Widget>[
            // El color ES la identidad de la etiqueta: glifo tintado con el
            // color resuelto de la paleta WhatsApp (no un dot pequeño).
            AppSwatchIcon(
              color: WaLabelPalette.resolve(label.color),
              icon: Icons.sell_outlined,
            ),
            const SizedBox(width: AppTokens.sp4),
            Expanded(
              child: Text(
                label.name,
                style: textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTokens.text2, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Scrollable para que el pull-to-refresh funcione también con la lista vacía.
    return ListView(
      key: const Key('wa_labels.empty'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp6),
          child: Column(
            children: <Widget>[
              Text(
                'Sin etiquetas de WhatsApp',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.sp2),
              Text(
                'Las etiquetas que crees aquí o en WhatsApp aparecerán en esta '
                'lista.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final WaLabelsFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('wa_labels.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _message(failure),
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<WaLabelsBloc>().add(
                const WaLabelsLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _message(WaLabelsFailure f) => switch (f) {
    WaLabelsForbiddenFailure() =>
      'No tienes permiso para ver las etiquetas '
          'de este bot.',
    WaLabelsNotFoundFailure() => 'Este bot ya no existe en tu organización.',
    WaLabelsNetworkFailure() || WaLabelsTimeoutFailure() =>
      'Sin conexión. Revisa tu red e inténtalo de '
          'nuevo.',
    WaLabelsServerFailure() ||
    WaLabelsUnknownFailure() ||
    WaLabelsInvalidFailure() ||
    WaLabelsNotConnectedFailure() ||
    WaLabelsUpstreamFailure() => 'No pudimos cargar las etiquetas de WhatsApp.',
  };
}
