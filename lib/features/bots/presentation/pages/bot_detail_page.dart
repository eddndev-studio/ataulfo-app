import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../bloc/bot_detail_bloc.dart';

/// Detalle de un Bot (S04). Consume el `BotDetailBloc` del scope; el
/// cableado del provider y del ID lo hace el router en `/bots/:id`. Es
/// content-only: el Scaffold y el AppBar los aporta la ruta, igual que
/// en el listado para mantener consistencia con el shell.
class BotDetailPage extends StatelessWidget {
  const BotDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BotDetailBloc, BotDetailState>(
      builder: (context, state) => switch (state) {
        BotDetailLoading() => const _LoadingView(),
        BotDetailLoaded(bot: final bot) => _LoadedView(bot: bot),
        // Durante una mutación y tras un fallo de mutación el bot sigue
        // visible. Los controles inline (pausar / IA / renombrar) y el copy
        // de error se cablean en slices posteriores; aquí el snapshot basta.
        BotDetailMutating(bot: final bot) => _LoadedView(bot: bot),
        BotDetailMutationFailed(bot: final bot) => _LoadedView(bot: bot),
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
  const _LoadedView({required this.bot});

  final Bot bot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
