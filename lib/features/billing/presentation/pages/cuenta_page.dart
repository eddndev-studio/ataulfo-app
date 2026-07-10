import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_section_link.dart';
import '../../domain/entities/entitlement.dart';
import '../../domain/failures/billing_failure.dart';
import '../../domain/repositories/web_link_launcher.dart';
import '../bloc/entitlement_bloc.dart';
import '../cuenta_format.dart';

/// Pantalla Cuenta: el plan de la org SOLO-LECTURA (plan + estado de la IA +
/// consumo del periodo). Gestionar el plan (contratar, mejorar, pagar) vive
/// en el sitio web — cada CTA abre el navegador vía [WebLinkLauncher]; la
/// app no monta UI de cobro. Página content-only: la ruta aporta
/// Scaffold+AppBar.
///
/// La pausa de IA (cobro caído, prueba vencida o cupo agotado) se explica
/// con un banner y NUNCA alarma de más: los flujos deterministas y la
/// mensajería siguen funcionando siempre, y la pantalla lo dice explícito.
class CuentaPage extends StatelessWidget {
  const CuentaPage({
    super.key,
    required this.webBaseUrl,
    required this.launcher,
  });

  /// Base del sitio web público (no la API). Los paths de gestión
  /// (`/cuenta`, `/precios`) se concatenan tal cual.
  final String webBaseUrl;

  final WebLinkLauncher launcher;

  void _abrirWeb(String path) => unawaited(launcher.open('$webBaseUrl$path'));

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntitlementBloc, EntitlementState>(
      builder: (context, state) => switch (state) {
        EntitlementInitial() || EntitlementLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        // 404 = org sin suscripción: estado del producto con salida a la
        // web, no un error de carga (reintentar no lo cambiaría).
        EntitlementFailed(failure: BillingNotFoundFailure()) => _SinPlanView(
          onVerPlanes: () => _abrirWeb('/precios'),
        ),
        EntitlementFailed() => _ErrorView(
          onRetry: () => context.read<EntitlementBloc>().add(
            const EntitlementLoadRequested(),
          ),
        ),
        EntitlementLoaded(:final entitlement) => _LoadedView(
          entitlement: entitlement,
          onAbrirWeb: _abrirWeb,
        ),
      },
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.entitlement, required this.onAbrirWeb});

  final Entitlement entitlement;
  final ValueChanged<String> onAbrirWeb;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final estado = estadoIA(entitlement);
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
          _PlanCard(entitlement: entitlement, estado: estado),
          if (estado.kind != EstadoIAKind.activa) ...<Widget>[
            const SizedBox(height: AppTokens.sp5),
            _EstadoBanner(estado: estado, onAbrirWeb: onAbrirWeb),
          ],
          const SizedBox(height: AppTokens.sp5),
          _ConsumoCard(entitlement: entitlement),
          const SizedBox(height: AppTokens.sp5),
          // Reasurance SIEMPRE visible: el enforcement solo pausa la IA;
          // los flujos deterministas y los mensajes nunca se detienen.
          Text(
            'Tus flujos y mensajes automáticos siempre funcionan, incluso '
            'con la IA en pausa.',
            key: const Key('cuenta.reassurance'),
            style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp5),
          AppCard(
            child: AppSectionLink(
              rowKey: const Key('cuenta.manage_web'),
              icon: Icons.open_in_new,
              title: 'Gestionar plan en la web',
              caption: 'Planes, pagos y facturación',
              onTap: () => onAbrirWeb('/cuenta'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.entitlement, required this.estado});

  final Entitlement entitlement;
  final EstadoIA estado;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      key: const Key('cuenta.plan_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Tu plan',
            style: textTheme.titleMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp3),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  planLabel(entitlement.planCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: AppTokens.sp2),
              _pill(estado),
            ],
          ),
        ],
      ),
    );
  }

  /// Pausa dura (cobro/prueba) = danger; cupo agotado = pausa suave con dot
  /// atenuado (se resuelve solo al siguiente periodo); activa = dot verde.
  static AppPill _pill(EstadoIA estado) => switch (estado.kind) {
    EstadoIAKind.activa => AppPill.neutral(
      label: estado.pillLabel,
      dot: AppPillDot.active,
    ),
    EstadoIAKind.limiteAlcanzado => AppPill.neutral(
      label: estado.pillLabel,
      dot: AppPillDot.paused,
    ),
    EstadoIAKind.suscripcionInactiva ||
    EstadoIAKind.pruebaVencida => AppPill.danger(label: estado.pillLabel),
  };
}

class _EstadoBanner extends StatelessWidget {
  const _EstadoBanner({required this.estado, required this.onAbrirWeb});

  final EstadoIA estado;
  final ValueChanged<String> onAbrirWeb;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // La pausa dura se titula en danger; el límite (pausa suave que se
    // reinicia sola) mantiene el color base para no sobre-alarmar.
    final tituloColor = estado.kind == EstadoIAKind.limiteAlcanzado
        ? null
        : AppTokens.danger;
    final webPath = estado.webPath;
    return AppCard(
      key: const Key('cuenta.banner'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            estado.titulo ?? '',
            style: textTheme.titleMedium?.copyWith(color: tituloColor),
          ),
          const SizedBox(height: AppTokens.sp2),
          Text(
            estado.cuerpo ?? '',
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
          if (estado.ctaLabel != null && webPath != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            AppButton.tonal(
              key: const Key('cuenta.banner_cta'),
              label: estado.ctaLabel!,
              onPressed: () => onAbrirWeb(webPath),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConsumoCard extends StatelessWidget {
  const _ConsumoCard({required this.entitlement});

  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final e = entitlement;
    return AppCard(
      key: const Key('cuenta.consumo_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Consumo',
            style: textTheme.titleMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp3),
          _UsoRow(
            rowKey: const Key('cuenta.credits'),
            label: 'Créditos de IA',
            value: creditosLabel(e.creditsUsed, e.creditCap),
          ),
          // El almacenamiento solo existe en planes con galería de medios;
          // sin la feature la fila sobra (no hay dónde subir).
          if (e.features.contains('media_gallery')) ...<Widget>[
            const Divider(height: AppTokens.sp5, color: AppTokens.divider),
            _UsoRow(
              rowKey: const Key('cuenta.storage'),
              label: 'Almacenamiento',
              value: almacenamientoLabel(e.storageUsedMb, e.storageQuotaMb),
            ),
          ],
          // El contador de imágenes es ADITIVO en el wire: un backend que
          // aún no lo emite no pinta la fila (no se inventa "0 de 0").
          if (e.imageGen case final imageGen?) ...<Widget>[
            const Divider(height: AppTokens.sp5, color: AppTokens.divider),
            _UsoRow(
              rowKey: const Key('cuenta.image_gen'),
              label: 'Imágenes con IA',
              value: imagenesIaLabel(imageGen.used, imageGen.cap),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bloque label:valor del consumo. No hay primitivo de key/value en el kit;
/// se compone a mano con la misma jerarquía caption/valor de los hubs.
class _UsoRow extends StatelessWidget {
  const _UsoRow({
    required this.rowKey,
    required this.label,
    required this.value,
  });

  final Key rowKey;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: rowKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: 2),
        Text(value, style: textTheme.bodyMedium),
      ],
    );
  }
}

class _SinPlanView extends StatelessWidget {
  const _SinPlanView({required this.onVerPlanes});

  final VoidCallback onVerPlanes;

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
              'Aún no tienes un plan configurado.',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.sp4),
            AppButton.tonal(
              key: const Key('cuenta.no_plan_cta'),
              label: 'Ver planes',
              onPressed: onVerPlanes,
            ),
          ],
        ),
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
              'No se pudo cargar tu plan.',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.sp4),
            AppButton.tonal(
              key: const Key('cuenta.retry'),
              label: 'Reintentar',
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
