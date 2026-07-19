import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../domain/entities/quick_reply.dart';
import '../bloc/quick_replies_bloc.dart';

/// Selector ⚡ de respuestas rápidas WhatsApp Business (S23). Lista las respuestas
/// ACTIVAS del bot (atajo + mensaje); tocar una cierra el sheet devolviendo su
/// `message` para que el composer lo inserte en el campo de texto.
///
/// La hoja observa el bloc que ya precarga el hilo: abre incluso si el catálogo
/// sigue en vuelo y cambia a contenido (o error) sin exigir un segundo toque.
/// Como una ruta modal no hereda automáticamente los providers del llamador,
/// [open] captura la instancia antes de crearla y la comparte con
/// [BlocProvider.value].
class QuickRepliesSheet extends StatelessWidget {
  const QuickRepliesSheet({super.key});

  /// Abre el selector y resuelve con el `message` elegido, o `null` si se cierra
  /// sin elegir.
  static Future<String?> open(BuildContext context) {
    final bloc = context.read<QuickRepliesBloc>();
    return showAppBottomSheet<String>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<QuickRepliesBloc>.value(
        value: bloc,
        child: const QuickRepliesSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      key: const Key('quick_replies_sheet'),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6 + context.sheetBottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Respuestas rápidas', style: textTheme.titleLarge),
          const SizedBox(height: AppTokens.sp4),
          BlocBuilder<QuickRepliesBloc, QuickRepliesState>(
            builder: (context, state) => switch (state) {
              QuickRepliesLoading() => const SizedBox(
                key: Key('quick_replies_sheet.loading'),
                height: 144,
                child: AppLoadingIndicator(
                  label: 'Cargando respuestas rápidas…',
                ),
              ),
              QuickRepliesLoaded(:final items) => _LoadedReplies(items: items),
              QuickRepliesFailed() => KeyedSubtree(
                key: const Key('quick_replies_sheet.error'),
                child: AppErrorState(
                  message: 'No se pudieron cargar las respuestas rápidas',
                  description: 'Comprueba tu conexión e inténtalo de nuevo.',
                  onRetry: () => context.read<QuickRepliesBloc>().add(
                    const QuickRepliesLoadRequested(),
                  ),
                  retryLabel: 'Reintentar',
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _LoadedReplies extends StatelessWidget {
  const _LoadedReplies({required this.items});

  final List<QuickReply> items;

  @override
  Widget build(BuildContext context) {
    final active = items.where((q) => !q.deleted).toList(growable: false);
    if (active.isEmpty) {
      return Padding(
        key: const Key('quick_replies_sheet.empty'),
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp4),
        child: Text(
          'No hay respuestas rápidas guardadas. Créalas desde la app de '
          'WhatsApp Business de este número.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: active
          .map<Widget>((q) => _QuickReplyTile(quickReply: q))
          .toList(growable: false),
    );
  }
}

class _QuickReplyTile extends StatelessWidget {
  const _QuickReplyTile({required this.quickReply});

  final QuickReply quickReply;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: Key('quick_reply.${quickReply.waQuickReplyId}'),
      onTap: () => Navigator.of(context).pop(quickReply.message),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              quickReply.shortcut,
              style: textTheme.titleSmall?.copyWith(color: AppTokens.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTokens.sp1),
            Text(
              quickReply.message,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
