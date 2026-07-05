import 'package:flutter/material.dart';

import '../../../../core/ai/ai_config.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_select_field.dart';
import '../../../../core/design/widgets/app_toggle_row.dart';

/// Sheet del seguimiento por inactividad: toggle + espera + intentos. La
/// espera se elige de un set cerrado (el backend valida 30 min..30 días) y
/// los intentos 1..3. Devuelve el AIConfig completo ya copiado.
class AiConfigFollowUpSheet extends StatefulWidget {
  const AiConfigFollowUpSheet({
    super.key,
    required this.keyPrefix,
    required this.initial,
  });

  final String keyPrefix;
  final AIConfig initial;

  @override
  State<AiConfigFollowUpSheet> createState() => _AiConfigFollowUpSheetState();
}

class _AiConfigFollowUpSheetState extends State<AiConfigFollowUpSheet> {
  static const Map<String, int> _delays = <String, int>{
    '30 minutos': 30,
    '1 hora': 60,
    '3 horas': 180,
    '6 horas': 360,
    '12 horas': 720,
    '24 horas': 1440,
    '2 días': 2880,
    '3 días': 4320,
    '7 días': 10080,
  };

  late bool _enabled = widget.initial.followUpEnabled;
  late int _delay = widget.initial.followUpDelayMinutes > 0
      ? widget.initial.followUpDelayMinutes
      : 1440;
  late int _attempts = widget.initial.followUpMaxAttempts > 0
      ? widget.initial.followUpMaxAttempts
      : 1;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
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
            Text('Seguimiento por inactividad', style: textTheme.titleLarge),
            const SizedBox(height: AppTokens.sp4),
            AppToggleRow(
              switchKey: Key('${widget.keyPrefix}.sheet.follow_up.enabled'),
              label: 'Dar seguimiento automático',
              caption:
                  'Si el cliente no responde tras un tiempo, el bot decide si '
                  'enviar UN seguimiento útil (o no enviar nada). Un mensaje '
                  'del cliente reinicia el ciclo.',
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            if (_enabled) ...<Widget>[
              const SizedBox(height: AppTokens.sp4),
              AppSelectField<int>(
                key: Key('${widget.keyPrefix}.sheet.follow_up.delay'),
                label: 'Esperar',
                value: _delay,
                // Un delay guardado fuera del set (p. ej. fijado por el agente
                // de plataforma) se muestra como entrada propia: el sheet
                // JAMÁS aparenta un valor distinto del que Guardar persiste.
                options: <AppSelectOption<int>>[
                  if (!_delays.containsValue(_delay))
                    AppSelectOption<int>(_delay, '$_delay min (personalizado)'),
                  for (final e in _delays.entries)
                    AppSelectOption<int>(e.value, e.key),
                ],
                onChanged: (v) => setState(() => _delay = v ?? 1440),
              ),
              const SizedBox(height: AppTokens.sp4),
              AppSelectField<int>(
                key: Key('${widget.keyPrefix}.sheet.follow_up.attempts'),
                label: 'Intentos máximos por ciclo',
                value: _attempts.clamp(1, 3),
                options: const <AppSelectOption<int>>[
                  AppSelectOption<int>(1, '1'),
                  AppSelectOption<int>(2, '2'),
                  AppSelectOption<int>(3, '3'),
                ],
                onChanged: (v) => setState(() => _attempts = v ?? 1),
              ),
            ],
            const SizedBox(height: AppTokens.sp4),
            AppButton.filled(
              key: Key('${widget.keyPrefix}.sheet.follow_up.save'),
              label: 'Guardar',
              onPressed: () => Navigator.of(context).pop(
                widget.initial.copyWith(
                  followUpEnabled: _enabled,
                  followUpDelayMinutes: _delay,
                  followUpMaxAttempts: _attempts,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
