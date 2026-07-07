import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../domain/entities/org_branding.dart';

/// Logo del membrete de los documentos: preview del guardado (URL firmada,
/// best-effort), elegirlo de la galería y restablecer la marca. La galería
/// en modo picker ya permite subir un archivo nuevo, así que "elegir"
/// cubre también "subir".
class DocumentLogoSection extends StatelessWidget {
  const DocumentLogoSection({
    super.key,
    required this.branding,
    required this.saving,
    required this.onPickLogo,
    required this.onReset,
  });

  final OrgBranding branding;
  final bool saving;
  final VoidCallback onPickLogo;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      key: const Key('org_customization.card.logo'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Logo de los documentos',
            style: textTheme.labelMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp4),
          Row(
            children: <Widget>[
              _LogoPreview(branding: branding),
              const SizedBox(width: AppTokens.sp4),
              Expanded(
                child: Text(
                  branding.hasLogo
                      ? 'Los documentos nuevos salen con este logo junto '
                            'al nombre de la organización.'
                      : 'Aún sin logo: los documentos salen con la marca '
                            'de Ataúlfo hasta que configures la tuya.',
                  style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.sp4),
          AppButton.filled(
            key: const Key('org_customization.pick_logo'),
            label: branding.hasLogo
                ? 'Cambiar logo'
                : 'Elegir logo de la galería',
            fullWidth: true,
            onPressed: saving ? null : onPickLogo,
          ),
          if (branding.configured) ...<Widget>[
            const SizedBox(height: AppTokens.sp2),
            AppButton.text(
              key: const Key('org_customization.reset'),
              label: 'Restablecer marca',
              fullWidth: true,
              onPressed: saving ? null : onReset,
            ),
          ],
          const SizedBox(height: AppTokens.sp2),
          Text(
            'Se aplica a los documentos nuevos; el PNG o JPEG se elige de '
            'la galería de medios (ahí mismo puedes subirlo).',
            style: textTheme.bodySmall?.copyWith(color: AppTokens.textDisabled),
          ),
        ],
      ),
    );
  }
}

/// Miniatura del logo guardado. La URL firmada expira: un fetch fallido cae
/// al placeholder sin romper la página (la marca guardada sigue intacta).
class _LogoPreview extends StatelessWidget {
  const _LogoPreview({required this.branding});

  final OrgBranding branding;

  @override
  Widget build(BuildContext context) {
    const double side = 64;
    final Widget child;
    if (branding.hasLogo && branding.logoUrl.isNotEmpty) {
      child = Image.network(
        branding.logoUrl,
        key: const Key('org_customization.logo_preview'),
        width: side,
        height: side,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _LogoPlaceholder(),
      );
    } else if (branding.hasLogo) {
      // Hay logo pero sin URL (firma caída): icono de imagen, no el vacío.
      child = const Icon(
        Icons.image_outlined,
        size: 28,
        color: AppTokens.text2,
      );
    } else {
      child = const _LogoPlaceholder();
    }
    return Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTokens.surface2,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.divider),
      ),
      child: child,
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.business_outlined,
      size: 28,
      color: AppTokens.textDisabled,
    );
  }
}
