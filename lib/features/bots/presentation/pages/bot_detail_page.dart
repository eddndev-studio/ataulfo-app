import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/role_privilege.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../bloc/bot_detail_bloc.dart';
import '../widgets/bot_ai_toggle.dart';
import '../widgets/bot_clone_sheet.dart';
import '../widgets/bot_edit_sheet.dart';
import '../widgets/bot_toggle_row.dart';

/// Detalle de un Bot (S04). Consume el `BotDetailBloc` del scope; el
/// cableado del provider y del ID lo hace el router en `/bots/:id`. Es
/// content-only: el Scaffold y el AppBar los aporta la ruta, igual que
/// en el listado para mantener consistencia con el shell.
///
/// Centro de mando: WORKER ve el detalle (la ruta es WORKER+), pero todos
/// los controles de mutación están gateados ADMIN+ leyendo `Identity.role`
/// del `AuthBloc` global. El gateo es cosmético; la autoridad real es el
/// 403 del backend.
class BotDetailPage extends StatelessWidget {
  const BotDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isAdmin =
        authState is AuthAuthenticated &&
        isAdminOrAbove(authState.identity.role);
    return BlocBuilder<BotDetailBloc, BotDetailState>(
      builder: (context, state) => switch (state) {
        BotDetailLoading() => const _LoadingView(),
        BotDetailLoaded(bot: final bot) => _LoadedView(
          bot: bot,
          isAdmin: isAdmin,
        ),
        // Durante una mutación el bot sigue visible con los controles
        // inhabilitados; tras un fallo, visible con el copy de error.
        BotDetailMutating(bot: final bot) => _LoadedView(
          bot: bot,
          isAdmin: isAdmin,
          isMutating: true,
        ),
        BotDetailMutationFailed(bot: final bot, failure: final f) =>
          _LoadedView(bot: bot, isAdmin: isAdmin, failure: f),
        // Transitorio: el listener ya navegó al clon; el bloc vuelve a Loaded
        // enseguida. Un frame de spinner evita parpadeo.
        BotDetailCloneSucceeded() => const _LoadingView(),
        BotDetailFailed(failure: final f) => _FailedView(failure: f),
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
  const _LoadedView({
    required this.bot,
    required this.isAdmin,
    this.isMutating = false,
    this.failure,
  });

  final Bot bot;

  /// El operador alcanza ADMIN+ → ve y opera los controles de mutación.
  final bool isAdmin;

  /// Hay un PUT en vuelo → los controles quedan inhabilitados.
  final bool isMutating;

  /// Última mutación fallida (copy inline en danger). Null = sin error.
  final BotsFailure? failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final f = failure;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6 + context.safeBottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppAvatar(name: bot.name, size: 64),
              const SizedBox(width: AppTokens.sp4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(bot.name, style: textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      _channelLabel(bot.channel),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTokens.text2,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                IconButton(
                  key: const Key('bot_detail.edit'),
                  tooltip: 'Editar bot',
                  icon: const Icon(Icons.edit_outlined, color: AppTokens.text2),
                  onPressed: isMutating
                      ? null
                      : () => BotEditSheet.openEdit(context, bot),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.sp6),
          Wrap(
            spacing: AppTokens.sp2,
            runSpacing: AppTokens.sp2,
            children: <Widget>[
              AppPill.outline(label: 'v${bot.version}'),
              if (bot.paused)
                const AppPill.neutral(label: 'Pausado', dot: AppPillDot.paused)
              else
                const AppPill.primary(label: 'Activo', dot: AppPillDot.active),
              // IA off es estado de configuración, no error → neutral.
              // El pill solo aparece cuando aiDisabled=true; el caso default
              // (IA habilitada) no se verbaliza para no saturar el header.
              if (bot.aiDisabled)
                const AppPill.neutral(
                  label: 'IA deshabilitada',
                  dot: AppPillDot.paused,
                ),
            ],
          ),
          if (isAdmin) ...<Widget>[
            const SizedBox(height: AppTokens.sp6),
            BotToggleRow(
              switchKey: const Key('bot_detail.paused'),
              label: 'Pausar bot',
              caption:
                  'Pausado, el bot deja de procesar mensajes hasta que lo '
                  'reanudes; no se reanuda solo.',
              value: bot.paused,
              onChanged: isMutating
                  ? null
                  : (v) => context.read<BotDetailBloc>().add(
                      BotDetailUpdateRequested(paused: v),
                    ),
            ),
            const SizedBox(height: AppTokens.sp5),
            BotAiToggle(bot: bot, isMutating: isMutating),
          ],
          if (f != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            Text(
              _failureMessage(f),
              key: const Key('bot_detail.mutation_error'),
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
            ),
          ],
          if (bot.identifier != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp6),
            Text(
              'Identificador',
              style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp1),
            SelectableText(bot.identifier!, style: textTheme.bodyMedium),
          ],
          const SizedBox(height: AppTokens.sp7),
          AppButton.tonal(
            label: 'Conversaciones',
            fullWidth: true,
            onPressed: () => context.push('/bots/${bot.id}/sessions'),
          ),
          const SizedBox(height: AppTokens.sp3),
          AppButton.tonal(
            label: 'Etiquetas de WhatsApp',
            fullWidth: true,
            onPressed: () => context.push('/bots/${bot.id}/wa-labels'),
          ),
          const SizedBox(height: AppTokens.sp3),
          AppButton.filled(
            label: 'Conectar WhatsApp',
            fullWidth: true,
            onPressed: () => context.push('/bots/${bot.id}/connect'),
          ),
          if (isAdmin) ...<Widget>[
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              key: const Key('bot_detail.variables'),
              label: 'Variables',
              fullWidth: true,
              onPressed: () => context.push('/bots/${bot.id}/variables'),
            ),
            const SizedBox(height: AppTokens.sp7),
            AppButton.tonal(
              key: const Key('bot_detail.clone'),
              label: 'Clonar bot',
              fullWidth: true,
              onPressed: isMutating
                  ? null
                  : () => BotCloneSheet.open(
                      context,
                      onCloned: (newId) => context.push('/bots/$newId'),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  // Duplicado intencional con BotsListPage._BotTile._channelLabel: regla
  // de 3 — al tercer consumidor extraer a un helper compartido en
  // `core/bots/` o similar (hoy son dos lugares).
  static String _channelLabel(BotChannel c) => switch (c) {
    BotChannel.waUnofficial => 'WhatsApp',
    BotChannel.waba => 'WhatsApp Business',
  };

  // Copy inline de un fallo de mutación. El 409 (conflicto de versión) ya
  // disparó un re-GET en el bloc: el snapshot está fresco, sólo falta avisar
  // y que el operador reintente.
  static String _failureMessage(BotsFailure f) => switch (f) {
    BotsConflictFailure() =>
      'Tu edición estaba desactualizada; la refrescamos. Revisa y reintenta.',
    BotsInvalidCreateFailure() =>
      'Revisa los datos del bot: el cambio no es válido.',
    BotsForbiddenFailure() => 'Tu rol no permite editar este bot.',
    BotsNotFoundFailure() => 'Este bot ya no existe en tu organización.',
    BotsNetworkFailure() ||
    BotsTimeoutFailure() => 'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    BotsServerFailure() ||
    UnknownBotsFailure() => 'No pudimos guardar el cambio. Inténtalo de nuevo.',
  };
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final BotsFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is BotsNotFoundFailure;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: isNotFound
          ? const Key('bot_detail.error.not_found')
          : const Key('bot_detail.error.generic'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              isNotFound
                  ? 'Este bot ya no existe en tu organización'
                  : 'No pudimos cargar el detalle del bot',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<BotDetailBloc>().add(
                const BotDetailLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
