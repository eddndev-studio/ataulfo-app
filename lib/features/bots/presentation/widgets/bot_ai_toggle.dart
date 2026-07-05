import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/widgets/app_toggle_row.dart';
import '../../../templates/domain/entities/template.dart';
import '../../../templates/domain/repositories/templates_repository.dart';
import '../../domain/entities/bot.dart';
import '../bloc/bot_detail_bloc.dart';

/// Toggle "Deshabilitar IA" del detalle de un Bot (S04). El interruptor sólo
/// controla `bot.ai_disabled`; la IA EFECTIVA es `template.ai.enabled &&
/// !bot.aiDisabled` — el bot únicamente puede DESHABILITAR lo que la plantilla
/// habilita.
///
/// Para resolver la IA efectiva hace falta `template.ai.enabled`, que vive tras
/// un endpoint ADMIN+ (`GET /templates/:id`). Este widget se monta SÓLO en el
/// render ADMIN+ del detalle, así que el fetch del Template nunca ocurre en la
/// carga compartida (que también sirve a WORKER, sin acceso a ese endpoint).
///
/// Degradación cuidadosa: mientras el Template carga, el toggle queda inerte
/// con un aviso; si el fetch falla, el toggle SIGUE operable (el flag del bot
/// es real y editable) con una nota — no se falsea el estado efectivo. Si la
/// plantilla tiene la IA apagada, el toggle es inerte y se explica por qué.
class BotAiToggle extends StatefulWidget {
  const BotAiToggle({super.key, required this.bot, required this.isMutating});

  final Bot bot;
  final bool isMutating;

  @override
  State<BotAiToggle> createState() => _BotAiToggleState();
}

class _BotAiToggleState extends State<BotAiToggle> {
  late final Future<Template> _template;

  @override
  void initState() {
    super.initState();
    // `read` en initState no se suscribe; sólo resuelve el repo del scope.
    _template = context.read<TemplatesRepository>().byId(widget.bot.templateId);
  }

  void _toggle(bool aiDisabled) => context.read<BotDetailBloc>().add(
    BotDetailUpdateRequested(aiDisabled: aiDisabled),
  );

  @override
  Widget build(BuildContext context) {
    final aiDisabled = widget.bot.aiDisabled;
    return FutureBuilder<Template>(
      future: _template,
      builder: (context, snap) {
        const switchKey = Key('bot_detail.ai');
        const label = 'Deshabilitar IA';

        if (snap.connectionState != ConnectionState.done) {
          return const AppToggleRow(
            switchKey: switchKey,
            label: label,
            caption: 'Comprobando la IA de la plantilla…',
            value: false,
            onChanged: null,
          );
        }

        if (snap.hasError) {
          // No sabemos si la plantilla habilita IA; el flag del bot sí es real.
          return AppToggleRow(
            switchKey: switchKey,
            label: label,
            caption:
                'No pudimos verificar la IA de la plantilla; el cambio se '
                'aplicará igual.',
            value: aiDisabled,
            onChanged: widget.isMutating ? null : _toggle,
          );
        }

        final templateAiEnabled = snap.data!.ai.enabled;
        if (!templateAiEnabled) {
          // La plantilla apaga la IA: deshabilitarla aquí no cambia nada.
          return AppToggleRow(
            switchKey: switchKey,
            label: label,
            caption:
                'La plantilla tiene la IA apagada; actívala en la plantilla '
                'para usarla en este bot.',
            value: aiDisabled,
            onChanged: null,
          );
        }

        final effective = !aiDisabled;
        return AppToggleRow(
          switchKey: switchKey,
          label: label,
          caption: effective
              ? 'La IA está activa para este bot.'
              : 'La IA está desactivada para este bot.',
          value: aiDisabled,
          onChanged: widget.isMutating ? null : _toggle,
        );
      },
    );
  }
}
