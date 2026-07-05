import 'package:flutter/material.dart';

import '../../../../core/ai/ai_config.dart';
import '../../../../core/ai/tool_groups_sheet.dart';
import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_toggle_row.dart';
import '../../domain/entities/catalog.dart';
import 'ai_config_follow_up_sheet.dart';
import 'ai_config_model_sheets.dart';
import 'ai_config_stat_tile.dart';
import 'ai_config_summaries.dart';
import 'ai_config_value_sheets.dart';
import 'thinking_label.dart';

/// Campos que el [AiConfigEditor] puede pintar. Cada superficie consumidora
/// declara su subconjunto: la plantilla edita todos; los defaults de la org
/// solo los básicos (los campos de silencio/tool-groups/subagente/seguimiento
/// son semántica de plantilla).
enum AiConfigField {
  enabled,
  model,
  temperature,
  thinking,
  contextMessages,
  responseDelay,
  silenceLabels,
  toolGroups,
  subagent,
  followUp,
}

/// Picker del campo de etiquetas de silencio, inyectado por el consumidor:
/// el catálogo de etiquetas (bloc, sheet) es semántica de plantilla y no vive
/// en este editor. Recibe la selección actual y devuelve la nueva lista de
/// ids, o `null` si se cerró sin guardar.
typedef AiConfigSilenceLabelsPicker =
    Future<List<String>?> Function(BuildContext context, List<String> current);

/// Editor por-campo de un [AIConfig]: información Y edición en la misma
/// superficie. Cada stat tile es tappable y abre un control enfocado
/// (picker del catálogo agrupado por proveedor, slider, choices, número);
/// el toggle de habilitado muta directo. Cada edición emite por [onChanged]
/// el AIConfig completo con UN campo cambiado — el consumidor decide si eso
/// es un PUT inmediato (plantilla) o una edición acumulada (org).
///
/// El catálogo gobierna capacidades: un modelo sin `supportsTemperature` /
/// `supportsThinking` deja su tile como solo-lectura ("Fija del modelo").
/// Elegir un modelo de otro proveedor cambia también el proveedor (el picker
/// agrupa por proveedor). Las keys de tiles y sheets se derivan de
/// [keyPrefix], de modo que cada superficie conserva keys propias y estables.
class AiConfigEditor extends StatelessWidget {
  const AiConfigEditor({
    super.key,
    required this.keyPrefix,
    required this.ai,
    required this.catalog,
    required this.fields,
    required this.editable,
    required this.onChanged,
    required this.enabledLabel,
    required this.enabledCaption,
    this.pickSilenceLabels,
  });

  /// Prefijo de todas las keys (`<prefijo>.tile.model`, `<prefijo>.sheet.…`).
  final String keyPrefix;

  final AIConfig ai;

  /// Catálogo vivo de modelos. `null` mientras carga: los pickers que lo
  /// exigen (modelo, subagente) quedan inertes; el resto sigue editable.
  final Catalog? catalog;

  /// Subconjunto de campos que esta superficie edita.
  final Set<AiConfigField> fields;

  /// false = controles inertes (mutación o guardado en vuelo).
  final bool editable;

  final ValueChanged<AIConfig> onChanged;

  /// Rótulo y caption del toggle de habilitado (el copy depende de si el
  /// toggle gobierna una plantilla o los defaults de la org).
  final String enabledLabel;
  final String enabledCaption;

  /// Requerido si [fields] incluye [AiConfigField.silenceLabels]; sin picker
  /// el tile se pinta inerte.
  final AiConfigSilenceLabelsPicker? pickSilenceLabels;

  AIModel? get _modelInfo {
    final cat = catalog;
    if (cat == null) return null;
    for (final p in cat.providers) {
      for (final m in p.models) {
        if (m.id == ai.model) return m;
      }
    }
    return null;
  }

  bool _has(AiConfigField f) => fields.contains(f);

  @override
  Widget build(BuildContext context) {
    final info = _modelInfo;
    // Sin catálogo (o modelo fuera de tabla) asumimos editable: el backend
    // valida de todas formas; bloquear sería inventar una restricción.
    final canTemperature = info?.supportsTemperature ?? true;
    final canThinking = info?.supportsThinking ?? true;

    // Bloques de la grilla en orden fijo; los gaps se intercalan al final
    // para que un campo oculto no deje un hueco doble.
    final blocks = <Widget>[];

    final modelTile = _has(AiConfigField.model)
        ? AiConfigStatTile(
            tileKey: Key('$keyPrefix.tile.model'),
            label: 'Modelo',
            value: ai.model,
            // El picker exige catálogo: sin tabla no hay opciones.
            onTap: !editable || catalog == null
                ? null
                : () => _pickModel(context),
          )
        : null;
    final temperatureTile = _has(AiConfigField.temperature)
        ? AiConfigStatTile(
            tileKey: Key('$keyPrefix.tile.temperature'),
            label: 'Temperatura',
            value: ai.temperature.toStringAsFixed(1),
            note: canTemperature ? null : 'Fija del modelo',
            onTap: !editable || !canTemperature
                ? null
                : () => _pickTemperature(context),
          )
        : null;
    _addPair(blocks, modelTile, temperatureTile);

    final thinkingTile = _has(AiConfigField.thinking)
        ? AiConfigStatTile(
            tileKey: Key('$keyPrefix.tile.thinking'),
            label: 'Razonamiento',
            value: thinkingLabel(ai.thinkingLevel),
            note: canThinking ? null : 'Fija del modelo',
            onTap: !editable || !canThinking
                ? null
                : () => _pickThinking(context),
          )
        : null;
    final contextTile = _has(AiConfigField.contextMessages)
        ? AiConfigStatTile(
            tileKey: Key('$keyPrefix.tile.context'),
            label: 'Mensajes de contexto',
            value: ai.contextMessages.toString(),
            onTap: !editable ? null : () => _pickContext(context),
          )
        : null;
    _addPair(blocks, thinkingTile, contextTile);

    if (_has(AiConfigField.responseDelay)) {
      blocks.add(
        AiConfigStatTile(
          tileKey: Key('$keyPrefix.tile.delay'),
          label: 'Retraso de respuesta',
          value: ai.responseDelaySeconds == 0
              ? 'Inmediato'
              : '${ai.responseDelaySeconds}s',
          onTap: !editable ? null : () => _pickDelay(context),
        ),
      );
    }
    if (_has(AiConfigField.silenceLabels)) {
      blocks.add(
        AiConfigStatTile(
          tileKey: Key('$keyPrefix.tile.silence_labels'),
          label: 'Etiquetas de silencio',
          value: silenceLabelsSummary(ai.silenceLabelIds.length),
          onTap: !editable || pickSilenceLabels == null
              ? null
              : () => _pickSilence(context),
        ),
      );
    }
    if (_has(AiConfigField.toolGroups)) {
      blocks.add(
        AiConfigStatTile(
          tileKey: Key('$keyPrefix.tile.tool_groups'),
          label: 'Permisos de herramientas',
          value: toolGroupsSummary(ai.disabledToolGroups),
          onTap: !editable ? null : () => _pickToolGroups(context),
        ),
      );
    }
    if (_has(AiConfigField.subagent)) {
      blocks.add(
        AiConfigStatTile(
          tileKey: Key('$keyPrefix.tile.subagent'),
          label: 'Modelo de subagentes',
          value: ai.subagent?.model ?? 'Heredado',
          // El picker exige catálogo: sin tabla no hay opciones (igual que
          // el tile de modelo principal).
          onTap: !editable || catalog == null
              ? null
              : () => _pickSubagent(context),
        ),
      );
    }
    if (_has(AiConfigField.followUp)) {
      blocks.add(
        AiConfigStatTile(
          tileKey: Key('$keyPrefix.tile.follow_up'),
          label: 'Seguimiento por inactividad',
          value: followUpSummary(ai),
          onTap: !editable ? null : () => _pickFollowUp(context),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_has(AiConfigField.enabled)) ...<Widget>[
          // El toggle muta directo (un campo, una emisión).
          AppToggleRow(
            switchKey: Key('$keyPrefix.enabled'),
            label: enabledLabel,
            caption: enabledCaption,
            value: ai.enabled,
            onChanged: editable
                ? (v) => onChanged(ai.copyWith(enabled: v))
                : null,
          ),
          const SizedBox(height: AppTokens.sp5),
        ],
        for (var i = 0; i < blocks.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppTokens.cardGap),
          blocks[i],
        ],
      ],
    );
  }

  /// Fila de dos tiles a la misma altura; con uno solo visible ocupa todo el
  /// ancho, y sin ninguno no agrega nada.
  static void _addPair(List<Widget> blocks, Widget? a, Widget? b) {
    if (a != null && b != null) {
      blocks.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: a),
              const SizedBox(width: AppTokens.cardGap),
              Expanded(child: b),
            ],
          ),
        ),
      );
    } else if (a != null || b != null) {
      blocks.add(a ?? b!);
    }
  }

  Future<void> _pickModel(BuildContext context) async {
    final cat = catalog;
    if (cat == null) return;
    final picked =
        await showAppBottomSheet<({AIProvider provider, String model})>(
          context,
          isScrollControlled: true,
          backgroundColor: AppTokens.surface1,
          builder: (_) => AiConfigModelSheet(
            keyPrefix: keyPrefix,
            catalog: cat,
            current: ai.model,
          ),
        );
    if (picked == null || !context.mounted) return;
    onChanged(ai.copyWith(provider: picked.provider, model: picked.model));
  }

  Future<void> _pickSubagent(BuildContext context) async {
    final cat = catalog;
    if (cat == null) return;
    // El resultado se envuelve en un record para distinguir "cerrar sin
    // elegir" (null) de "elegir Heredar" (selection: null).
    final picked = await showAppBottomSheet<({SubagentModel? selection})>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => AiConfigSubagentSheet(
        keyPrefix: keyPrefix,
        catalog: cat,
        current: ai.subagent,
      ),
    );
    if (picked == null || !context.mounted) return;
    onChanged(ai.copyWith(subagent: picked.selection));
  }

  Future<void> _pickTemperature(BuildContext context) async {
    final picked = await showAppBottomSheet<double>(
      context,
      backgroundColor: AppTokens.surface1,
      builder: (_) => AiConfigTemperatureSheet(
        keyPrefix: keyPrefix,
        initial: ai.temperature,
      ),
    );
    if (picked == null || !context.mounted) return;
    onChanged(ai.copyWith(temperature: picked));
  }

  Future<void> _pickThinking(BuildContext context) async {
    final picked = await showAppBottomSheet<ThinkingLevel>(
      context,
      backgroundColor: AppTokens.surface1,
      builder: (_) => AiConfigThinkingSheet(
        keyPrefix: keyPrefix,
        current: ai.thinkingLevel,
      ),
    );
    if (picked == null || !context.mounted) return;
    onChanged(ai.copyWith(thinkingLevel: picked));
  }

  Future<void> _pickContext(BuildContext context) async {
    final picked = await showAppBottomSheet<int>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => AiConfigContextSheet(
        keyPrefix: keyPrefix,
        initial: ai.contextMessages,
      ),
    );
    if (picked == null || !context.mounted) return;
    onChanged(ai.copyWith(contextMessages: picked));
  }

  Future<void> _pickDelay(BuildContext context) async {
    final picked = await showAppBottomSheet<int>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => AiConfigDelaySheet(
        keyPrefix: keyPrefix,
        initial: ai.responseDelaySeconds,
      ),
    );
    if (picked == null || !context.mounted) return;
    onChanged(ai.copyWith(responseDelaySeconds: picked));
  }

  Future<void> _pickSilence(BuildContext context) async {
    final picker = pickSilenceLabels;
    if (picker == null) return;
    final picked = await picker(context, ai.silenceLabelIds);
    if (picked == null || !context.mounted) return;
    onChanged(ai.copyWith(silenceLabelIds: picked));
  }

  Future<void> _pickToolGroups(BuildContext context) async {
    // Catálogo de grupos estático del cliente: el sheet no necesita bloc.
    final picked = await showAppBottomSheet<List<String>>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) =>
          ToolGroupsSheet(initialDisabledGroups: ai.disabledToolGroups),
    );
    if (picked == null || !context.mounted) return;
    onChanged(ai.copyWith(disabledToolGroups: picked));
  }

  Future<void> _pickFollowUp(BuildContext context) async {
    final picked = await showAppBottomSheet<AIConfig>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => AiConfigFollowUpSheet(keyPrefix: keyPrefix, initial: ai),
    );
    if (picked == null || !context.mounted) return;
    onChanged(picked);
  }
}
