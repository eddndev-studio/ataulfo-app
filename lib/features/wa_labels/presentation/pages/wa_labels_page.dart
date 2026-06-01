import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../domain/entities/wa_label.dart';
import '../../domain/failures/wa_labels_failure.dart';
import '../bloc/wa_labels_bloc.dart';
import '../widgets/wa_label_swatch.dart';

/// Catálogo de etiquetas WhatsApp del bot (S21). Consume el `WaLabelsBloc` del
/// scope (la ruta `/bots/:id/wa-labels` lo cabla con el botId). Content-only: el
/// Scaffold y el AppBar los aporta la ruta, como el resto de las sub-secciones
/// del bot.
///
/// Lee el espejo y pinta solo las etiquetas activas (filtra tombstones); el
/// swatch resuelve el índice de paleta de WhatsApp. Se actualiza en vivo por SSE
/// `label.wa.*` sin recargar.
class WaLabelsPage extends StatelessWidget {
  const WaLabelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WaLabelsBloc, WaLabelsState>(
      builder: (context, state) => switch (state) {
        WaLabelsLoading() => const _LoadingView(),
        WaLabelsLoaded(labels: final labels) => _LoadedView(labels: labels),
        WaLabelsFailed(failure: final f) => _FailedView(failure: f),
      },
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
        await bloc.stream.firstWhere(
          (s) =>
              (s is WaLabelsLoaded && !s.isRefreshing) || s is WaLabelsFailed,
        );
      },
      child: active.isEmpty
          ? const _EmptyView()
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppTokens.sp4,
                AppTokens.sp4,
                AppTokens.sp4,
                AppTokens.sp4 + context.safeBottomInset,
              ),
              itemCount: active.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTokens.cardGap),
              itemBuilder: (_, i) => _WaLabelTile(label: active[i]),
            ),
    );
  }
}

class _WaLabelTile extends StatelessWidget {
  const _WaLabelTile({required this.label});

  final WaLabel label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: <Widget>[
          WaLabelSwatch(colorIndex: label.color),
          const SizedBox(width: AppTokens.sp4),
          Expanded(
            child: Text(
              label.name,
              style: textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
              onPressed: () =>
                  context.read<WaLabelsBloc>().add(const WaLabelsLoadRequested()),
            ),
          ],
        ),
      ),
    );
  }

  static String _message(WaLabelsFailure f) => switch (f) {
    WaLabelsForbiddenFailure() => 'No tienes permiso para ver las etiquetas '
        'de este bot.',
    WaLabelsNotFoundFailure() => 'Este bot ya no existe en tu organización.',
    WaLabelsNetworkFailure() ||
    WaLabelsTimeoutFailure() => 'Sin conexión. Revisa tu red e inténtalo de '
        'nuevo.',
    WaLabelsServerFailure() ||
    WaLabelsUnknownFailure() ||
    WaLabelsInvalidFailure() ||
    WaLabelsNotConnectedFailure() ||
    WaLabelsUpstreamFailure() => 'No pudimos cargar las etiquetas de WhatsApp.',
  };
}
