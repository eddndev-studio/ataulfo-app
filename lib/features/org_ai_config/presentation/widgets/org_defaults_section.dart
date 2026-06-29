import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/provider_badge.dart';
import '../../../ai_catalog/domain/entities/catalog.dart';
import '../../../templates/domain/entities/template.dart';

/// Editor de los defaults de IA de la org: proveedor/modelo + perillas que
/// heredan las plantillas NUEVAS al crearse. Sin estado propio: lee `defaults`
/// y emite el AIConfig editado por [onChanged] (la fuente de verdad es el bloc).
///
/// Controles sin caja de texto (dropdowns + steppers) a propósito: evita la
/// fricción de sincronizar TextEditingControllers contra el bloc. El system
/// prompt por defecto NO se edita aquí (las plantillas nuevas nacen con prompt
/// vacío, como hoy; el prompt se ajusta por plantilla).
class OrgDefaultsSection extends StatelessWidget {
  const OrgDefaultsSection({
    super.key,
    required this.catalog,
    required this.defaults,
    required this.enabled,
    required this.onChanged,
  });

  final Catalog catalog;
  final AIConfig defaults;
  final bool enabled;
  final void Function(AIConfig) onChanged;

  AIModel? get _modelInfo {
    for (final p in catalog.providers) {
      for (final m in p.models) {
        if (m.id == defaults.model) return m;
      }
    }
    return null;
  }

  ProviderEntry? _entryFor(AIProvider provider) {
    final wire = provider.toWire();
    for (final p in catalog.providers) {
      if (p.provider == wire) return p;
    }
    return null;
  }

  /// Proveedores del catálogo que el enum cliente reconoce (drift ⇒ se omite,
  /// no se ofrece algo que la app no sabe aplicar).
  List<AIProvider> get _providers {
    final out = <AIProvider>[];
    for (final p in catalog.providers) {
      try {
        out.add(AIProvider.fromWire(p.provider));
      } on ArgumentError {
        // Proveedor del wire desconocido para este cliente: se omite.
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final info = _modelInfo;
    final canTemperature = info?.supportsTemperature ?? true;
    final canThinking = info?.supportsThinking ?? true;
    final models = _entryFor(defaults.provider)?.models ?? const <AIModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Valores por defecto', style: textTheme.titleMedium),
        const SizedBox(height: AppTokens.sp1),
        Text(
          'Lo que heredan las plantillas nuevas de la organización al crearse. '
          'No afecta a las plantillas existentes.',
          style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp2),
        _row(
          'IA activa por defecto',
          Align(
            alignment: Alignment.centerRight,
            child: Switch(
              key: const Key('org_ai.defaults.enabled'),
              value: defaults.enabled,
              onChanged: enabled
                  ? (v) => onChanged(defaults.copyWith(enabled: v))
                  : null,
            ),
          ),
        ),
        _row(
          'Proveedor',
          DropdownButton<AIProvider>(
            key: const Key('org_ai.defaults.provider'),
            value: _providers.contains(defaults.provider)
                ? defaults.provider
                : null,
            isExpanded: true,
            onChanged: enabled ? _onProviderChanged : null,
            items: <DropdownMenuItem<AIProvider>>[
              for (final p in _providers)
                DropdownMenuItem<AIProvider>(
                  value: p,
                  child: Text(ProviderBadge.labelOf(p)),
                ),
            ],
          ),
        ),
        _row(
          'Modelo',
          DropdownButton<String>(
            key: const Key('org_ai.defaults.model'),
            value: models.any((m) => m.id == defaults.model)
                ? defaults.model
                : null,
            isExpanded: true,
            onChanged: enabled
                ? (m) {
                    if (m != null) onChanged(defaults.copyWith(model: m));
                  }
                : null,
            items: <DropdownMenuItem<String>>[
              for (final m in models)
                DropdownMenuItem<String>(value: m.id, child: Text(m.id)),
            ],
          ),
        ),
        if (canTemperature)
          _stepperRow(
            'Temperatura',
            const Key('org_ai.defaults.temperature'),
            defaults.temperature.toStringAsFixed(1),
            onMinus: () => _bumpTemp(-0.1),
            onPlus: () => _bumpTemp(0.1),
          )
        else
          _fixedRow('Temperatura', 'Fija del modelo'),
        if (canThinking)
          _row(
            'Razonamiento',
            DropdownButton<ThinkingLevel>(
              key: const Key('org_ai.defaults.thinking'),
              value: defaults.thinkingLevel,
              isExpanded: true,
              onChanged: enabled
                  ? (t) {
                      if (t != null) {
                        onChanged(defaults.copyWith(thinkingLevel: t));
                      }
                    }
                  : null,
              items: <DropdownMenuItem<ThinkingLevel>>[
                for (final t in ThinkingLevel.values)
                  DropdownMenuItem<ThinkingLevel>(
                    value: t,
                    child: Text(t.toWire()),
                  ),
              ],
            ),
          )
        else
          _fixedRow('Razonamiento', 'Fijo del modelo'),
        _stepperRow(
          'Mensajes de contexto',
          const Key('org_ai.defaults.context'),
          '${defaults.contextMessages}',
          onMinus: () => _bumpContext(-1),
          onPlus: () => _bumpContext(1),
        ),
        _stepperRow(
          'Retraso de respuesta (s)',
          const Key('org_ai.defaults.delay'),
          '${defaults.responseDelaySeconds}',
          onMinus: () => _bumpDelay(-10),
          onPlus: () => _bumpDelay(10),
        ),
      ],
    );
  }

  void _onProviderChanged(AIProvider? p) {
    if (p == null) return;
    final entry = _entryFor(p);
    // Al cambiar de proveedor, el modelo salta al recomendado del nuevo
    // (el modelo previo es de otra familia y no aplica).
    final model =
        entry?.defaultModel ??
        (entry?.models.isNotEmpty ?? false
            ? entry!.models.first.id
            : defaults.model);
    onChanged(defaults.copyWith(provider: p, model: model));
  }

  void _bumpTemp(double delta) {
    final v = (defaults.temperature + delta).clamp(0.0, 2.0);
    onChanged(
      defaults.copyWith(temperature: double.parse(v.toStringAsFixed(1))),
    );
  }

  void _bumpContext(int delta) {
    final v = (defaults.contextMessages + delta).clamp(1, 100);
    onChanged(defaults.copyWith(contextMessages: v));
  }

  void _bumpDelay(int delta) {
    final v = (defaults.responseDelaySeconds + delta).clamp(0, 120);
    onChanged(defaults.copyWith(responseDelaySeconds: v));
  }

  Widget _row(String label, Widget control) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
    child: Row(
      children: <Widget>[
        Expanded(flex: 2, child: Text(label)),
        Expanded(flex: 3, child: control),
      ],
    ),
  );

  Widget _fixedRow(String label, String note) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppTokens.sp2),
    child: Row(
      children: <Widget>[
        Expanded(flex: 2, child: Text(label)),
        Expanded(
          flex: 3,
          child: Text(note, style: const TextStyle(color: AppTokens.text2)),
        ),
      ],
    ),
  );

  Widget _stepperRow(
    String label,
    Key valueKey,
    String value, {
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        IconButton(
          onPressed: enabled ? onMinus : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 44,
          child: Text(value, key: valueKey, textAlign: TextAlign.center),
        ),
        IconButton(
          onPressed: enabled ? onPlus : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    ),
  );
}
