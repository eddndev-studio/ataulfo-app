import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_header_card.dart';
import '../../../../core/design/widgets/app_swatch_icon.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/util/user_greeting.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/label.dart';
import '../../domain/failures/labels_failure.dart';
import '../bloc/labels_admin_bloc.dart';
import '../widgets/label_dot.dart';
import '../widgets/label_edit_sheet.dart';

/// Cuerpo de la sección "Etiquetas" (S10), org-scoped. Es una tab del shell con
/// header rico propio (la tarjeta-header full-bleed ES su encabezado, como en
/// Bots/Plantillas — el shell no monta AppBar para esta tab; el FAB de crear sí
/// lo aporta el shell). Consume el `LabelsAdminBloc` del scope: pinta el
/// catálogo con buscador client-side, abre la hoja de edición al tocar una
/// etiqueta y deja recargar con pull-to-refresh.
class LabelsAdminPage extends StatefulWidget {
  const LabelsAdminPage({super.key, this.onOpenSettings});

  /// Acción del avatar del header → abrir Ajustes. La aporta el shell (que
  /// controla los tabs). Sin ella, el avatar es no-op.
  final VoidCallback? onOpenSettings;

  @override
  State<LabelsAdminPage> createState() => _LabelsAdminPageState();
}

class _LabelsAdminPageState extends State<LabelsAdminPage> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    // Cada keystroke re-filtra la lista visible (client-side); un setState basta.
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  String _emailFromSession(BuildContext context) {
    final state = context.read<AuthBloc>().state;
    return switch (state) {
      AuthAuthenticated(:final identity) => identity.email,
      AuthAuthenticatedNoOrg(:final identity) => identity.email,
      _ => '',
    };
  }

  List<Label> _applyFilter(List<Label> items) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where(
          (l) =>
              l.name.toLowerCase().contains(q) ||
              l.description.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<LabelsAdminBloc>();
    bloc.add(const LabelsAdminRefreshRequested());
    // `orElse` evita un StateError si el bloc se cierra (el operador cambia
    // de tab) mientras el refresh sigue en vuelo.
    await bloc.stream.firstWhere(
      (s) =>
          (s is LabelsAdminLoaded && !s.isRefreshing) || s is LabelsAdminFailed,
      orElse: () => bloc.state,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LabelsAdminBloc, LabelsAdminState>(
      builder: (context, state) => switch (state) {
        LabelsAdminLoading() => const _LoadingView(),
        LabelsAdminLoaded(labels: final labels) ||
        LabelsAdminMutating(labels: final labels) ||
        LabelsAdminMutationFailed(
          labels: final labels,
        ) => _buildLoaded(context, labels),
        LabelsAdminFailed(failure: final f) => _FailedView(failure: f),
      },
    );
  }

  Widget _buildLoaded(BuildContext context, List<Label> labels) {
    final filtered = _applyFilter(labels);
    final user = userGreeting(_emailFromSession(context));
    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Sin padding aquí: el header es full-bleed y va pegado arriba. El
        // resto del contenido lleva su propio padding más abajo.
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppHeaderCard(
              greeting: user.greeting,
              title: 'Etiquetas',
              avatarInitial: user.initial,
              onAvatarTap: widget.onOpenSettings ?? () {},
              watermark: Icons.label,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppTokens.sp5,
                AppTokens.sp5,
                AppTokens.sp5,
                AppTokens.sp5 + context.safeBottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (labels.isEmpty)
                    const _EmptyCopy()
                  else ...<Widget>[
                    AppTextField(
                      key: const Key('labels_admin.search'),
                      label: 'Buscar etiqueta',
                      hint: 'Nombre o descripción',
                      controller: _searchCtrl,
                    ),
                    const SizedBox(height: AppTokens.sp5),
                    if (filtered.isEmpty)
                      const _NoResults()
                    else
                      for (final label in filtered) ...<Widget>[
                        _LabelTile(label: label),
                        const SizedBox(height: AppTokens.cardGap),
                      ],
                  ],
                ],
              ),
            ),
          ],
        ),
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
    // onTap nativo del AppCard: ripple/highlight del InkWell interno
    // (el GestureDetector externo dejaba el tap sin feedback visual).
    return AppCard(
      onTap: () => LabelEditSheet.openEdit(context, label),
      child: Row(
        children: <Widget>[
          // El color ES la identidad de la etiqueta: glifo tintado con
          // presencia (no un dot de 16px perdido en la card).
          AppSwatchIcon(color: parseLabelHex(label.color)),
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

/// La búsqueda no dejó etiquetas visibles (pero sí las hay en la org).
class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('labels_admin.no_results'),
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp6),
      child: Center(
        child: Text(
          'Ninguna etiqueta coincide con tu búsqueda.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
        ),
      ),
    );
  }
}

/// Catálogo vacío. Vive BAJO el header (la sección no pierde identidad ni el
/// avatar) y deja el pull-to-refresh activo.
class _EmptyCopy extends StatelessWidget {
  const _EmptyCopy();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('labels_admin.empty'),
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp7),
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
