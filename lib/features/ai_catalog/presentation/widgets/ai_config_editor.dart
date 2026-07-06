import 'package:flutter/material.dart';

import '../../../../core/ai/ai_config.dart';
import '../../../../core/ai/tool_groups_sheet.dart';
import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/app_selection_sheet.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_toggle_row.dart';
import '../../domain/entities/catalog.dart';
import 'ai_config_follow_up_sheet.dart';
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
/// superficie. Cada stat tile ocupa el ancho completo (fila de formulario,
/// no mosaico) y abre un control enfocado en una hoja; el toggle de
/// habilitado muta directo. Cada edición emite por [onChanged] el AIConfig
/// completo con UN campo cambiado — el consumidor decide si eso es un PUT
/// inmediato (plantilla) o una edición acumulada (org, [deferredSave]).
///
/// El catálogo gobierna capacidades: un modelo sin `supportsTemperature` /
/// `supportsThinking` deja su tile como solo-lectura ("Fija del modelo").
/// Mientras el catálogo carga, los tiles que lo exigen (modelo, subagente)
/// quedan inertes-atenuados sin perder su affordance. Elegir un modelo de
/// otro proveedor cambia también el proveedor (el picker agrupa por
/// proveedor). Las keys de tiles y opciones se derivan de [keyPrefix], de
/// modo que cada superficie conserva keys propias y estables.
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
    this.deferredSave = false,
    this.pickSilenceLabels,
  });

  /// Prefijo de todas las keys (`<prefijo>.tile.model`, `<prefijo>.model.…`).
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

  /// True cuando el consumidor acumula las ediciones en un borrador y el
  /// guardado real vive fuera (org): los sheets con confirmación rematan en
  /// 'Aplicar' para no aparentar una persistencia que no ocurre.
  final bool deferredSave;

  /// Requerido si [fields] incluye [AiConfigField.silenceLabels]; sin picker
  /// el tile se pinta inerte.
  final AiConfigSilenceLabelsPicker? pickSilenceLabels;

  String get _confirmLabel => deferredSave ? 'Aplicar' : 'Guardar';

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

    final blocks = <Widget>[
      if (_has(AiConfigField.model))
        AiConfigStatTile(
          tileKey: Key('$keyPrefix.tile.model'),
          label: 'Modelo',
          value: ai.model,
          // El picker exige catálogo: mientras no llega, inerte-atenuado.
          enabled: editable && catalog != null,
          onTap: () => _pickModel(context),
        ),
      if (_has(AiConfigField.temperature))
        AiConfigStatTile(
          tileKey: Key('$keyPrefix.tile.temperature'),
          label: 'Temperatura',
          value: ai.temperature.toStringAsFixed(1),
          note: canTemperature ? null : 'Fija del modelo',
          enabled: editable,
          onTap: canTemperature ? () => _pickTemperature(context) : null,
        ),
      if (_has(AiConfigField.thinking))
        AiConfigStatTile(
          tileKey: Key('$keyPrefix.tile.thinking'),
          label: 'Razonamiento',
          value: thinkingLabel(ai.thinkingLevel),
          note: canThinking ? null : 'Fija del modelo',
          enabled: editable,
          onTap: canThinking ? () => _pickThinking(context) : null,
        ),
      if (_has(AiConfigField.contextMessages))
        AiConfigStatTile(
          tileKey: Key('$keyPrefix.tile.context'),
          label: 'Mensajes de contexto',
          value: ai.contextMessages.toString(),
          enabled: editable,
          onTap: () => _pickContext(context),
        ),
      if (_has(AiConfigField.responseDelay))
        AiConfigStatTile(
          tileKey: Key('$keyPrefix.tile.delay'),
          label: 'Retraso de respuesta',
          value: ai.responseDelaySeconds == 0
              ? 'Inmediato'
              : '${ai.responseDelaySeconds}s',
          enabled: editable,
          onTap: () => _pickDelay(context),
        ),
      if (_has(AiConfigField.silenceLabels))
        AiConfigStatTile(
          tileKey: Key('$keyPrefix.tile.silence_labels'),
          label: 'Etiquetas de silencio',
          value: silenceLabelsSummary(ai.silenceLabelIds.length),
          enabled: editable && pickSilenceLabels != null,
          onTap: pickSilenceLabels == null ? null : () => _pickSilence(context),
        ),
      if (_has(AiConfigField.toolGroups))
        AiConfigStatTile(
          tileKey: Key('$keyPrefix.tile.tool_groups'),
          label: 'Permisos de herramientas',
          value: toolGroupsSummary(ai.disabledToolGroups),
          enabled: editable,
          onTap: () => _pickToolGroups(context),
        ),
      if (_has(AiConfigField.subagent))
        AiConfigStatTile(
          tileKey: Key('$keyPrefix.tile.subagent'),
          label: 'Modelo de subagentes',
          value: ai.subagent?.model ?? 'Heredado',
          // El picker exige catálogo, igual que el tile de modelo principal.
          enabled: editable && catalog != null,
          onTap: () => _pickSubagent(context),
        ),
      if (_has(AiConfigField.followUp))
        AiConfigStatTile(
          tileKey: Key('$keyPrefix.tile.follow_up'),
          label: 'Seguimiento por inactividad',
          value: followUpSummary(ai),
          enabled: editable,
          onTap: () => _pickFollowUp(context),
        ),
    ];

    // Filas a lo ancho, como toda superficie de ajustes de la app: la
    // jerarquía la dan las alturas y los gaps, no una grilla.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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

  /// Caption de modalidades de ENTRADA de un modelo: qué adjuntos del cliente
  /// puede VER. Sin flags = solo texto, sin ruido (null).
  static String? _modalityCaption(AIModel m) {
    final parts = <String>[
      if (m.supportsImageInput) 'imagen',
      if (m.supportsAudioInput) 'audio',
      if (m.supportsDocumentInput) 'documentos',
    ];
    if (parts.isEmpty) return null;
    return 'Ve: ${parts.join(' · ')}';
  }

  /// Secciones por proveedor para los pickers de modelo. Un proveedor que
  /// este release no reconoce se omite: no podemos construir el AIProvider
  /// del PUT (el backend puede ir adelante).
  List<AppSelectionSection<T>> _providerSections<T>(
    T Function(AIProvider provider, AIModel model) valueOf,
    String Function(AIModel model) keyOf,
  ) {
    final sections = <AppSelectionSection<T>>[];
    for (final entry in catalog?.providers ?? const <ProviderEntry>[]) {
      final AIProvider provider;
      try {
        provider = AIProvider.fromWire(entry.provider);
      } on ArgumentError {
        continue;
      }
      sections.add(
        AppSelectionSection<T>(
          header: entry.provider,
          options: <AppSelectionOption<T>>[
            for (final m in entry.models)
              AppSelectionOption<T>(
                key: Key(keyOf(m)),
                value: valueOf(provider, m),
                title: m.id,
                caption: _modalityCaption(m),
              ),
          ],
        ),
      );
    }
    return sections;
  }

  Future<void> _pickModel(BuildContext context) async {
    if (catalog == null) return;
    final picked =
        await showAppSelectionSheet<({AIProvider provider, String model})>(
          context,
          title: 'Modelo',
          searchHint: 'Buscar modelo',
          selected: (provider: ai.provider, model: ai.model),
          sections: _providerSections(
            (provider, m) => (provider: provider, model: m.id),
            (m) => '$keyPrefix.model.${m.id}',
          ),
        );
    if (picked == null || !context.mounted) return;
    onChanged(ai.copyWith(provider: picked.provider, model: picked.model));
  }

  Future<void> _pickSubagent(BuildContext context) async {
    if (catalog == null) return;
    // El resultado se envuelve en un record para distinguir "cerrar sin
    // elegir" (null) de "elegir Heredar" (selection: null).
    final picked = await showAppSelectionSheet<({SubagentModel? selection})>(
      context,
      title: 'Modelo de subagentes',
      searchHint: 'Buscar modelo',
      selected: (selection: ai.subagent),
      sections: <AppSelectionSection<({SubagentModel? selection})>>[
        AppSelectionSection<({SubagentModel? selection})>(
          options: <AppSelectionOption<({SubagentModel? selection})>>[
            AppSelectionOption<({SubagentModel? selection})>(
              key: Key('$keyPrefix.subagent.inherit'),
              value: (selection: null),
              title: 'Heredar (modelo principal)',
              caption: 'Los subagentes corren con el modelo de la plantilla.',
            ),
          ],
        ),
        ..._providerSections(
          (provider, m) =>
              (selection: SubagentModel(provider: provider, model: m.id)),
          (m) => '$keyPrefix.subagent.model.${m.id}',
        ),
      ],
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
        confirmLabel: _confirmLabel,
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
        confirmLabel: _confirmLabel,
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
        confirmLabel: _confirmLabel,
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
      builder: (_) => AiConfigFollowUpSheet(
        keyPrefix: keyPrefix,
        initial: ai,
        confirmLabel: _confirmLabel,
      ),
    );
    if (picked == null || !context.mounted) return;
    onChanged(picked);
  }
}
