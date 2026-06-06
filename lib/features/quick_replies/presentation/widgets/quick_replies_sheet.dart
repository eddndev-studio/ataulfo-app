import 'package:flutter/material.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../domain/entities/quick_reply.dart';

/// Selector ⚡ de respuestas rápidas WhatsApp Business (S23). Lista las respuestas
/// ACTIVAS del bot (atajo + mensaje); tocar una cierra el sheet devolviendo su
/// `message` para que el composer lo inserte en el campo de texto.
///
/// Stateless y sin bloc: recibe el catálogo ya cargado y filtra los tombstones
/// (`deleted:true`). Un sheet modal se monta en una ruta nueva que NO hereda los
/// providers del llamador, así que tomar una instantánea de la lista (en vez de
/// leer un bloc dentro) evita un `ProviderNotFoundException`; el coste es que la
/// lista no se refresca en vivo mientras el sheet está abierto, lo cual es
/// aceptable para un catálogo que casi nunca cambia.
class QuickRepliesSheet extends StatelessWidget {
  const QuickRepliesSheet({required this.items, super.key});

  final List<QuickReply> items;

  /// Abre el selector y resuelve con el `message` elegido, o `null` si se cierra
  /// sin elegir.
  static Future<String?> open(BuildContext context, List<QuickReply> items) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => QuickRepliesSheet(items: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final active = items.where((q) => !q.deleted).toList(growable: false);
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
          if (active.isEmpty)
            Padding(
              key: const Key('quick_replies_sheet.empty'),
              padding: const EdgeInsets.symmetric(vertical: AppTokens.sp4),
              child: Text(
                'No hay respuestas rápidas guardadas. Créalas desde la app de '
                'WhatsApp Business de este número.',
                style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              ),
            )
          else
            ...active.map((q) => _QuickReplyTile(quickReply: q)),
        ],
      ),
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
