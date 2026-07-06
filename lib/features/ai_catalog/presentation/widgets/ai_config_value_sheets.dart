import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ai/ai_config.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_option_row.dart';
import '../../../../core/design/widgets/app_slider.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import 'thinking_label.dart';

/// Slider de temperatura 0.0–2.0 con confirmación explícita. [confirmLabel]
/// lo inyecta el consumidor: 'Guardar' cuando elegir persiste al momento
/// (plantilla), 'Aplicar' cuando solo acumula en un borrador (org).
class AiConfigTemperatureSheet extends StatefulWidget {
  const AiConfigTemperatureSheet({
    super.key,
    required this.keyPrefix,
    required this.initial,
    this.confirmLabel = 'Guardar',
  });

  final String keyPrefix;
  final double initial;
  final String confirmLabel;

  @override
  State<AiConfigTemperatureSheet> createState() =>
      _AiConfigTemperatureSheetState();
}

class _AiConfigTemperatureSheetState extends State<AiConfigTemperatureSheet> {
  late double _value = widget.initial;

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
            Text('Temperatura', style: textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Baja = respuestas consistentes; alta = más creativas.',
              style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppSlider(
                    value: _value,
                    min: 0.0,
                    max: 2.0,
                    divisions: 20,
                    onChanged: (v) => setState(() => _value = v),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    _value.toStringAsFixed(1),
                    textAlign: TextAlign.end,
                    style: textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.sp4),
            AppButton.filled(
              key: Key('${widget.keyPrefix}.sheet.temperature.save'),
              label: widget.confirmLabel,
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(_value),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selector del nivel de razonamiento. Tap = elegir y cerrar.
class AiConfigThinkingSheet extends StatelessWidget {
  const AiConfigThinkingSheet({
    super.key,
    required this.keyPrefix,
    required this.current,
  });

  final String keyPrefix;
  final ThinkingLevel current;

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
            Text('Razonamiento', style: textTheme.titleLarge),
            const SizedBox(height: AppTokens.sp3),
            for (final level in ThinkingLevel.values)
              AppOptionRow(
                key: Key('$keyPrefix.thinking.${level.name}'),
                title: thinkingLabel(level),
                selected: level == current,
                onTap: () => Navigator.of(context).pop(level),
              ),
          ],
        ),
      ),
    );
  }
}

/// Campo numérico de mensajes de contexto con confirmación explícita.
/// [confirmLabel]: 'Guardar' (persiste al momento) o 'Aplicar' (acumula).
class AiConfigContextSheet extends StatefulWidget {
  const AiConfigContextSheet({
    super.key,
    required this.keyPrefix,
    required this.initial,
    this.confirmLabel = 'Guardar',
  });

  final String keyPrefix;
  final int initial;
  final String confirmLabel;

  @override
  State<AiConfigContextSheet> createState() => _AiConfigContextSheetState();
}

class _AiConfigContextSheetState extends State<AiConfigContextSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial.toString(),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int? get _parsed {
    final n = int.tryParse(_ctrl.text.trim());
    return (n == null || n < 1) ? null : n;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final parsed = _parsed;
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
            Text('Mensajes de contexto', style: textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Cuántos mensajes recientes del chat ve el motor en cada turno.',
              style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
            AppTextField(
              key: Key('${widget.keyPrefix}.sheet.context.field'),
              label: 'Mensajes',
              hint: 'p. ej. 20',
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
            const SizedBox(height: AppTokens.sp4),
            AppButton.filled(
              key: Key('${widget.keyPrefix}.sheet.context.save'),
              label: widget.confirmLabel,
              fullWidth: true,
              // _parsed se evalúa AL TAP (no al build): el closure no debe
              // congelar el valor de un frame anterior.
              onPressed: parsed == null
                  ? null
                  : () => Navigator.of(context).pop(_parsed),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo numérico de la ventana de acumulación (0..120 s) con confirmación
/// explícita ([confirmLabel]: 'Guardar' persiste / 'Aplicar' acumula).
/// 0 = responder de inmediato (comportamiento histórico).
class AiConfigDelaySheet extends StatefulWidget {
  const AiConfigDelaySheet({
    super.key,
    required this.keyPrefix,
    required this.initial,
    this.confirmLabel = 'Guardar',
  });

  final String keyPrefix;
  final int initial;
  final String confirmLabel;

  @override
  State<AiConfigDelaySheet> createState() => _AiConfigDelaySheetState();
}

class _AiConfigDelaySheetState extends State<AiConfigDelaySheet> {
  static const int _max = 120;

  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial.toString(),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int? get _parsed {
    final n = int.tryParse(_ctrl.text.trim());
    return (n == null || n < 0 || n > _max) ? null : n;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final parsed = _parsed;
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
            Text('Retraso de respuesta', style: textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Segundos que el bot acumula mensajes del cliente antes de '
              'responder todo junto. 0 = inmediato; máximo $_max.',
              style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
            AppTextField(
              key: Key('${widget.keyPrefix}.sheet.delay.field'),
              label: 'Segundos',
              hint: 'p. ej. 30',
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
            const SizedBox(height: AppTokens.sp4),
            AppButton.filled(
              key: Key('${widget.keyPrefix}.sheet.delay.save'),
              label: widget.confirmLabel,
              fullWidth: true,
              // _parsed se evalúa AL TAP (no al build): el closure no debe
              // congelar el valor de un frame anterior.
              onPressed: parsed == null
                  ? null
                  : () => Navigator.of(context).pop(_parsed),
            ),
          ],
        ),
      ),
    );
  }
}
