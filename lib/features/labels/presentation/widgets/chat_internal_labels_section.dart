import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../domain/entities/label.dart';
import '../bloc/chat_labels_bloc.dart';
import 'label_dot.dart';

/// Sección de SOLO LECTURA de las etiquetas INTERNAS (org-scoped) puestas a un
/// chat: las que aplican el operador, los flujos y el agente IA. Antes no se
/// veían en ninguna parte del cliente — esta sección las hace visibles, junto a
/// la sección WhatsApp (otro sistema de etiquetas). Una etiqueta interna mapeada
/// a WhatsApp se anota "también en WhatsApp" para que no se lea como duplicado.
/// Consume el `ChatLabelsBloc`.
class ChatInternalLabelsSection extends StatelessWidget {
  const ChatInternalLabelsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatLabelsBloc, ChatLabelsState>(
      builder: (context, state) => switch (state) {
        ChatLabelsLoading() => const _Loader(),
        ChatLabelsLoaded(:final applied, :final mapped) => _List(
          applied: applied,
          mapped: mapped,
        ),
        ChatLabelsFailed() => const _Error(),
      },
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppTokens.sp4),
    child: Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
        ),
      ),
    ),
  );
}

class _List extends StatelessWidget {
  const _List({required this.applied, required this.mapped});

  final List<Label> applied;
  final Set<String> mapped;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (applied.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp3),
        child: Text(
          'Este chat no tiene etiquetas internas.',
          style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final l in applied)
          _Row(label: l, alsoInWhatsApp: mapped.contains(l.id)),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.alsoInWhatsApp});

  final Label label;
  final bool alsoInWhatsApp;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp3),
      child: Row(
        children: <Widget>[
          LabelDot(hex: label.color, size: 18),
          const SizedBox(width: AppTokens.sp3),
          Expanded(
            child: Text(
              label.name,
              style: textTheme.bodyLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (alsoInWhatsApp) ...<Widget>[
            const SizedBox(width: AppTokens.sp2),
            Text(
              'también en WhatsApp',
              style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
            ),
          ],
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('chat_internal_labels.error'),
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'No pudimos cargar las etiquetas internas de este chat.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppTokens.sp2),
          AppButton.tonal(
            label: 'Reintentar',
            onPressed: () => context.read<ChatLabelsBloc>().add(
              const ChatLabelsLoadRequested(),
            ),
          ),
        ],
      ),
    );
  }
}
