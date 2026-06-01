import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../domain/entities/label.dart';
import '../../domain/failures/labels_failure.dart';
import '../bloc/labels_admin_bloc.dart';
import '../widgets/label_dot.dart';
import '../widgets/label_edit_sheet.dart';

/// Cuerpo de la sección "Etiquetas" (S10), org-scoped. Es una tab del shell, así
/// que NO trae Scaffold/AppBar propios (el shell aporta la barra y el FAB de
/// crear). Consume el `LabelsAdminBloc` del scope: pinta el catálogo, abre la
/// hoja de edición al tocar una etiqueta y deja recargar con pull-to-refresh.
class LabelsAdminPage extends StatelessWidget {
  const LabelsAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LabelsAdminBloc, LabelsAdminState>(
      builder: (context, state) => switch (state) {
        LabelsAdminLoading() => const _LoadingView(),
        LabelsAdminLoaded(labels: final labels) ||
        LabelsAdminMutating(labels: final labels) ||
        LabelsAdminMutationFailed(
          labels: final labels,
        ) => _LoadedView(labels: labels),
        LabelsAdminFailed(failure: final f) => _FailedView(failure: f),
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

  final List<Label> labels;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<LabelsAdminBloc>();
        bloc.add(const LabelsAdminRefreshRequested());
        // `orElse` evita un StateError si el bloc se cierra (el operador cambia
        // de tab) mientras el refresh sigue en vuelo.
        await bloc.stream.firstWhere(
          (s) =>
              (s is LabelsAdminLoaded && !s.isRefreshing) ||
              s is LabelsAdminFailed,
          orElse: () => bloc.state,
        );
      },
      child: labels.isEmpty
          ? const _EmptyView()
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppTokens.sp4,
                AppTokens.sp4,
                AppTokens.sp4,
                AppTokens.sp4 + context.safeBottomInset,
              ),
              itemCount: labels.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTokens.cardGap),
              itemBuilder: (_, i) => _LabelTile(label: labels[i]),
            ),
    );
  }
}

class _LabelTile extends StatelessWidget {
  const _LabelTile({required this.label});

  final Label label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasDescription = label.description.trim().isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => LabelEditSheet.openEdit(context, label),
      child: AppCard(
        child: Row(
          children: <Widget>[
            LabelDot(hex: label.color),
            const SizedBox(width: AppTokens.sp4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label.name,
                    style: textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasDescription) ...<Widget>[
                    const SizedBox(height: AppTokens.sp1),
                    Text(
                      label.description,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTokens.text2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
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
    return ListView(
      key: const Key('labels_admin.empty'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp6),
          child: Column(
            children: <Widget>[
              Text(
                'Sin etiquetas todavía',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.sp2),
              Text(
                'Crea etiquetas para clasificar conversaciones y dispararlas '
                'desde tus flujos.',
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

  final LabelsFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('labels_admin.error'),
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
              key: const Key('labels_admin.retry'),
              label: 'Reintentar',
              onPressed: () => context.read<LabelsAdminBloc>().add(
                const LabelsAdminLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _message(LabelsFailure f) => switch (f) {
    LabelsForbiddenFailure() =>
      'No tienes permiso para ver las etiquetas de la organización.',
    LabelsNetworkFailure() || LabelsTimeoutFailure() =>
      'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    LabelsServerFailure() ||
    LabelsUnknownFailure() ||
    LabelsValidationFailure() ||
    LabelsDuplicateNameFailure() ||
    LabelsNotFoundFailure() => 'No pudimos cargar las etiquetas.',
  };
}
