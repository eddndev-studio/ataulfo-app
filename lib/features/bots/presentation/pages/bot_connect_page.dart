import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../domain/entities/connect_link.dart';
import '../../domain/failures/bots_failure.dart';
import '../bloc/bot_connect_bloc.dart';

/// Pantalla "compartir enlace de conexión" (S04). Content-only: el Scaffold y
/// el AppBar los aporta la ruta `/bots/:id/connect`. Consume el
/// `BotConnectBloc` del scope, que arranca la sesión del bot y emite el
/// enlace público a compartir con quien sostiene el teléfono a vincular.
class BotConnectPage extends StatelessWidget {
  const BotConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BotConnectBloc, BotConnectState>(
      builder: (context, state) => switch (state) {
        BotConnectLoading() => const _LoadingView(),
        BotConnectReady(link: final link) => _ReadyView(link: link),
        BotConnectFailed(failure: final f) => _FailedView(failure: f),
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

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.link});

  final ConnectLink link;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.sp6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Comparte este enlace', style: textTheme.titleLarge),
          const SizedBox(height: AppTokens.sp2),
          Text(
            'Quien lo abra verá el código QR para escanear desde WhatsApp y '
            'vincular este bot. No necesita una cuenta.',
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp6),
          AppCard(
            child: SelectableText(
              link.url,
              key: const Key('bot_connect.url'),
              style: textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppTokens.sp3),
          AppButton.filled(
            label: 'Copiar enlace',
            fullWidth: true,
            onPressed: () => _copy(context),
          ),
          const SizedBox(height: AppTokens.sp4),
          Text(
            'Caduca a las ${_hhmm(link.expiresAt.toLocal())}. Si expira, '
            'vuelve a generarlo desde el detalle del bot.',
            style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: link.url));
    messenger.showSnackBar(const SnackBar(content: Text('Enlace copiado')));
  }

  /// Formato HH:mm sin depender de intl. La fecha llega del backend en UTC;
  /// el caller la pasa ya en hora local.
  static String _hhmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final BotsFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('bot_connect.error'),
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
                  context.read<BotConnectBloc>().add(const BotConnectStarted()),
            ),
          ],
        ),
      ),
    );
  }

  static String _message(BotsFailure f) => switch (f) {
    BotsForbiddenFailure() => 'No tienes permiso para conectar este bot.',
    BotsNotFoundFailure() => 'Este bot ya no existe en tu organización.',
    BotsNetworkFailure() ||
    BotsTimeoutFailure() => 'Sin conexión. Revisa tu red e intenta de nuevo.',
    _ => 'No pudimos preparar el enlace de conexión.',
  };
}
