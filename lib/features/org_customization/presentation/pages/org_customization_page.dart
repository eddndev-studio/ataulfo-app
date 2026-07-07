import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../auth/presentation/bloc/rename_org_cubit.dart';
import '../../../media/domain/entities/media_asset.dart';
import '../../../memberships/presentation/widgets/rename_org_sheet.dart';
import '../../domain/failures/org_branding_failure.dart';
import '../bloc/org_customization_cubit.dart';
import '../widgets/document_logo_section.dart';
import '../widgets/org_identity_section.dart';

/// Módulo de personalización de la organización: el nombre (renombrar reusa
/// la hoja de memberships) y el logo del membrete de los documentos que
/// genera el asistente. Página content-only: la ruta aporta Scaffold+AppBar.
///
/// El logo se elige de la galería de medios (`/media/pick?type=image`): la
/// galería ya sabe subir archivos nuevos, así que este módulo no duplica
/// plomería de upload. El backend guarda la marca ESTRUCTURADA (solo el
/// logo); el nombre viaja solo a los documentos — renombrar la org basta.
class OrgCustomizationPage extends StatelessWidget {
  const OrgCustomizationPage({super.key, this.pickLogo});

  /// Seam de test: cómo se obtiene el asset del logo. Default: la galería
  /// en modo picker filtrada a imágenes.
  final Future<MediaAsset?> Function(BuildContext context)? pickLogo;

  Future<MediaAsset?> _pick(BuildContext context) {
    final pick = pickLogo;
    if (pick != null) return pick(context);
    return context.push<MediaAsset>('/media/pick?type=image');
  }

  Future<void> _onPickLogo(BuildContext context) async {
    final cubit = context.read<OrgCustomizationCubit>();
    final state = cubit.state;
    if (state is! OrgCustomizationReady) return;

    final asset = await _pick(context);
    if (asset == null || !context.mounted) return;
    if (asset.contentType != 'image/png' && asset.contentType != 'image/jpeg') {
      // Mismo gate que el backend: \includegraphics traga PNG/JPEG sin
      // fricción; avisar aquí evita un 422 críptico.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El logo debe ser PNG o JPEG.')),
      );
      return;
    }
    if (state.branding.customTex) {
      final ok = await showAppConfirmDialog(
        context,
        title: '¿Reemplazar la plantilla de marca?',
        message:
            'El asistente guardó una plantilla de marca personalizada para '
            'esta organización. Al elegir un logo desde aquí se reemplaza '
            'por la marca estándar con tu logo.',
        confirmLabel: 'Reemplazar',
        destructive: false,
        confirmKey: const Key('org_customization.replace_confirm'),
      );
      if (!ok || !context.mounted) return;
    }
    unawaited(cubit.setLogo(asset.ref));
  }

  Future<void> _onReset(BuildContext context) async {
    final cubit = context.read<OrgCustomizationCubit>();
    final ok = await showAppConfirmDialog(
      context,
      title: '¿Restablecer la marca?',
      message:
          'Se quita el logo (y cualquier plantilla personalizada). Los '
          'documentos nuevos vuelven a la marca de Ataúlfo.',
      confirmLabel: 'Restablecer',
      destructive: true,
      confirmKey: const Key('org_customization.reset_confirm'),
    );
    if (ok) unawaited(cubit.reset());
  }

  Future<void> _onRename(BuildContext context, String currentName) async {
    final cubit = context.read<RenameOrgCubit>();
    final newName = await RenameOrgSheet.open(
      context,
      currentName: currentName,
    );
    if (newName == null) return;
    unawaited(cubit.rename(newName));
  }

  void _onRenameState(BuildContext context, RenameOrgState state) {
    switch (state) {
      case RenameOrgRenamed():
        // El nombre fresco se relee del backend; los documentos nuevos ya
        // salen con él (la marca estructurada lo toma al sembrar).
        unawaited(context.read<OrgCustomizationCubit>().load());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organización renombrada')),
        );
      case RenameOrgFailed():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo renombrar. Intenta de nuevo.'),
          ),
        );
      case RenameOrgIdle() || RenameOrgRenaming():
        break;
    }
  }

  void _onMutationFailure(BuildContext context, OrgBrandingFailure f) {
    final copy = switch (f) {
      OrgBrandingNetworkFailure() => 'Sin conexión. Intenta de nuevo.',
      OrgBrandingForbiddenFailure() =>
        'Tu rol no puede cambiar la personalización.',
      OrgBrandingInvalidFailure() =>
        'Ese archivo no sirve como logo (usa un PNG o JPEG de la galería).',
      OrgBrandingServerFailure() ||
      UnknownOrgBrandingFailure() => 'No se pudo guardar. Intenta de nuevo.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RenameOrgCubit, RenameOrgState>(
      listener: _onRenameState,
      child: BlocConsumer<OrgCustomizationCubit, OrgCustomizationState>(
        listenWhen: (prev, curr) =>
            curr is OrgCustomizationReady &&
            curr.mutationFailure != null &&
            (prev is! OrgCustomizationReady ||
                prev.mutationFailure != curr.mutationFailure),
        listener: (context, state) => _onMutationFailure(
          context,
          (state as OrgCustomizationReady).mutationFailure!,
        ),
        builder: (context, state) => switch (state) {
          OrgCustomizationLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          OrgCustomizationError() => _ErrorView(
            onRetry: () => context.read<OrgCustomizationCubit>().load(),
          ),
          OrgCustomizationReady() => _ReadyView(
            state: state,
            onRename: (name) => _onRename(context, name),
            onPickLogo: () => _onPickLogo(context),
            onReset: () => _onReset(context),
          ),
        },
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.state,
    required this.onRename,
    required this.onPickLogo,
    required this.onReset,
  });

  final OrgCustomizationReady state;
  final ValueChanged<String> onRename;
  final VoidCallback onPickLogo;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp5,
        AppTokens.sp5,
        AppTokens.sp5,
        AppTokens.sp5 + context.safeBottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          OrgIdentitySection(
            orgName: state.orgName,
            enabled: !state.saving,
            onRename: () => onRename(state.orgName),
          ),
          const SizedBox(height: AppTokens.sp5),
          DocumentLogoSection(
            branding: state.branding,
            saving: state.saving,
            onPickLogo: onPickLogo,
            onReset: onReset,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No se pudo cargar la personalización.',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.sp4),
            AppButton.tonal(
              key: const Key('org_customization.retry'),
              label: 'Reintentar',
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
