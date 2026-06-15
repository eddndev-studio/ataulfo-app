import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../labels/domain/repositories/chat_labels_repository.dart';
import '../../../labels/presentation/bloc/chat_labels_bloc.dart';
import '../../../labels/presentation/widgets/chat_internal_labels_section.dart';
import '../../../wa_labels/domain/repositories/wa_labels_repository.dart';
import '../../../wa_labels/presentation/bloc/wa_chat_labels_bloc.dart';
import '../../../wa_labels/presentation/widgets/wa_chat_labels_section.dart';
import '../../domain/entities/conversation.dart';

/// Hoja de etiquetas de un chat con DOS secciones que distinguen los dos
/// sistemas de etiquetas de la plataforma: **internas** (org-scoped; las que
/// aplican el operador, los flujos y el agente IA) y **WhatsApp** (per-bot;
/// espejo de las etiquetas de WhatsApp Business). Cada sección tiene su bloc y
/// su catálogo; una etiqueta interna mapeada a WhatsApp se anota como tal para
/// que no parezca duplicada.
///
/// Reemplaza al sheet WhatsApp-only: la bandeja y el hilo abren esta. Carga
/// fresco al abrir (no depende de que la bandeja esté en vivo), que era el punto
/// ciego: las etiquetas internas no se veían en ningún lado del cliente.
class ChatLabelsSheet extends StatelessWidget {
  const ChatLabelsSheet({super.key});

  /// Abre la hoja. Lee del scope el repo de etiquetas WhatsApp (sección WA +
  /// mapeos para la anotación) y el de Labels internos por chat (sección
  /// Internas, solo lectura). El `loadMappedLabelIds` resuelve qué etiquetas
  /// internas están mapeadas a WhatsApp (best-effort: si falla, sin anotación).
  static void open(
    BuildContext context, {
    required String botId,
    required String chatLid,
    required ConversationKind kind,
  }) {
    final waRepo = context.read<WaLabelsRepository>();
    final chatRepo = context.read<ChatLabelsRepository>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<ChatLabelsBloc>(
            create: (_) => ChatLabelsBloc(
              chatRepo: chatRepo,
              botId: botId,
              chatLid: chatLid,
              loadMappedLabelIds: () async {
                final mappings = await waRepo.listMappings(botId);
                return <String>{for (final m in mappings) m.labelId};
              },
            )..add(const ChatLabelsLoadRequested()),
          ),
          BlocProvider<WaChatLabelsBloc>(
            create: (_) => WaChatLabelsBloc(
              repo: waRepo,
              botId: botId,
              chatLid: chatLid,
              kind: kind,
            )..add(const WaChatLabelsLoadRequested()),
          ),
        ],
        child: const ChatLabelsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      key: const Key('chat_labels'),
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
          Text('Etiquetas de este chat', style: textTheme.titleLarge),
          const SizedBox(height: AppTokens.sp4),
          const _SectionHeader(icon: Icons.sell_outlined, title: 'Internas'),
          const ChatInternalLabelsSection(),
          const SizedBox(height: AppTokens.sp4),
          const Divider(color: AppTokens.divider, height: 1),
          const SizedBox(height: AppTokens.sp4),
          const _SectionHeader(
            icon: Icons.chat_bubble_outline,
            title: 'WhatsApp',
          ),
          const WaChatLabelsSection(),
        ],
      ),
    );
  }
}

/// Encabezado de sección: un glifo + el rótulo en mayúsculas tenues. Marca
/// visualmente a qué sistema de etiquetas pertenece la lista de abajo.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.sp1),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: AppTokens.text2),
          const SizedBox(width: AppTokens.sp2),
          Text(
            title.toUpperCase(),
            style: textTheme.labelMedium?.copyWith(
              color: AppTokens.text2,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
