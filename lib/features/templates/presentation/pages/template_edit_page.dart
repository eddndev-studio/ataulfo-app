import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_switch.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/provider_badge.dart';
import '../../../ai_catalog/domain/catalog_drift.dart';
import '../../../ai_catalog/domain/entities/catalog.dart';
import '../../../ai_catalog/domain/failures/catalog_failure.dart';
import '../../../ai_catalog/presentation/bloc/catalog_bloc.dart';
import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../bloc/template_edit_bloc.dart';

/// Página para editar una Template completa: name + systemPrompt +
/// AIConfig (enabled + provider + model + temperature + thinkingLevel +
/// contextMessages).
///
/// Content-only: el Scaffold y el AppBar los aporta la ruta. Dos blocs
/// page-scoped: `TemplateEditBloc` carga el template, `CatalogBloc`
/// carga la tabla de modelos. El form no renderea hasta que ambos
/// terminen (loading combinado prioriza el spinner por encima del form
/// parcial).
///
/// Cuando el template falla en cargar, gana sobre cualquier estado del
/// catálogo (no hay nada que editar). Cuando el template carga pero el
/// catálogo falla, mostramos el error específico del catálogo con su
/// retry — los pickers no pueden renderearse sin él.
///
/// Al persistir cambios (Succeeded), `pushReplacement` reemplaza la
/// ruta del editor con el detalle: el back físico vuelve al listado
/// sin pasar por el form que ya cumplió.
class TemplateEditPage extends StatelessWidget {
  const TemplateEditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TemplateEditBloc, TemplateEditState>(
      listenWhen: (prev, next) => next is TemplateEditSucceeded,
      listener: (context, state) {
        if (state is TemplateEditSucceeded) {
          context.pushReplacement('/templates/${state.template.id}');
        }
      },
      builder: (context, editState) {
        // El template gana sobre el catálogo en los estados terminales:
        // sin template no hay nada que editar; las fallas del catálogo
        // sólo importan si el template ya cargó.
        return switch (editState) {
          TemplateEditLoading() => const _LoadingView(),
          TemplateEditLoadFailed(failure: final f) => _LoadFailedView(
            failure: f,
          ),
          TemplateEditEditing(template: final t) => _RequireCatalog(
            template: t,
            submitting: false,
            submitFailure: null,
          ),
          TemplateEditSubmitting(template: final t) => _RequireCatalog(
            template: t,
            submitting: true,
            submitFailure: null,
          ),
          TemplateEditSubmitFailed(failure: final f, template: final t) =>
            _RequireCatalog(template: t, submitting: false, submitFailure: f),
          TemplateEditSucceeded(template: final t) => _RequireCatalog(
            template: t,
            submitting: true,
            submitFailure: null,
          ),
        };
      },
    );
  }
}

/// Gate del catálogo: render el form sólo cuando ambos blocs estén listos.
/// Aislado para mantener el switch de estados de edit legible y centralizar
/// las combinaciones template-loaded × catalog-{loading,failed,loaded}.
class _RequireCatalog extends StatelessWidget {
  const _RequireCatalog({
    required this.template,
    required this.submitting,
    required this.submitFailure,
  });

  final Template template;
  final bool submitting;
  final TemplatesFailure? submitFailure;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, catState) => switch (catState) {
        CatalogInitial() || CatalogLoading() => const _LoadingView(),
        CatalogFailed(failure: final f) => _CatalogFailedView(failure: f),
        CatalogLoaded(catalog: final c) => _EditForm(
          template: template,
          catalog: c,
          submitting: submitting,
          submitFailure: submitFailure,
        ),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
}

class _LoadFailedView extends StatelessWidget {
  const _LoadFailedView({required this.failure});

  final TemplatesFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final copy = failure is TemplatesNotFoundFailure
        ? 'Esta plantilla ya no existe en tu organización.'
        : 'No pudimos cargar la plantilla. Inténtalo de nuevo.';
    return Center(
      key: const Key('template_edit.load_error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(copy, textAlign: TextAlign.center, style: textTheme.bodyLarge),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<TemplateEditBloc>().add(
                const TemplateEditLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogFailedView extends StatelessWidget {
  const _CatalogFailedView({required this.failure});

  final CatalogFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final copy = switch (failure) {
      CatalogForbiddenFailure() =>
        'Tu rol no permite leer el catálogo de modelos. Pide acceso a un admin.',
      CatalogNetworkFailure() || CatalogTimeoutFailure() =>
        'Sin conexión para leer el catálogo de modelos. Revisa tu red y '
            'reintenta.',
      CatalogServerFailure() || UnknownCatalogFailure() =>
        'No pudimos leer el catálogo de modelos. Inténtalo de nuevo.',
    };
    return Center(
      key: const Key('template_edit.catalog_error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(copy, textAlign: TextAlign.center, style: textTheme.bodyLarge),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () =>
                  context.read<CatalogBloc>().add(const CatalogLoadRequested()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado inmutable del AIConfig editado por el operador.
///
/// El form mantiene este value object en setState y lo copia con
/// `copyWith` por cada interacción. Los controllers viven sólo para
/// los campos de texto libre (name, systemPrompt) y el numérico
/// (contextMessages, que necesita formato/teclado específico). El
/// resto (toggle, dropdowns, slider) usa el state directo.
@immutable
class _AIConfigFormState {
  const _AIConfigFormState({
    required this.enabled,
    required this.provider,
    required this.model,
    required this.temperature,
    required this.thinkingLevel,
  });

  factory _AIConfigFormState.fromAi(AIConfig ai) => _AIConfigFormState(
    enabled: ai.enabled,
    provider: ai.provider,
    model: ai.model,
    temperature: ai.temperature,
    thinkingLevel: ai.thinkingLevel,
  );

  final bool enabled;
  final AIProvider provider;
  final String model;
  final double temperature;
  final ThinkingLevel thinkingLevel;

  _AIConfigFormState copyWith({
    bool? enabled,
    AIProvider? provider,
    String? model,
    double? temperature,
    ThinkingLevel? thinkingLevel,
  }) => _AIConfigFormState(
    enabled: enabled ?? this.enabled,
    provider: provider ?? this.provider,
    model: model ?? this.model,
    temperature: temperature ?? this.temperature,
    thinkingLevel: thinkingLevel ?? this.thinkingLevel,
  );
}

class _EditForm extends StatefulWidget {
  const _EditForm({
    required this.template,
    required this.catalog,
    required this.submitting,
    required this.submitFailure,
  });

  final Template template;
  final Catalog catalog;
  final bool submitting;
  final TemplatesFailure? submitFailure;

  @override
  State<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends State<_EditForm> {
  late final TextEditingController _name;
  late final TextEditingController _systemPrompt;
  late final TextEditingController _contextMessages;
  late _AIConfigFormState _ai;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.template.name);
    _systemPrompt = TextEditingController(
      text: widget.template.ai.systemPrompt,
    );
    _contextMessages = TextEditingController(
      text: widget.template.ai.contextMessages.toString(),
    );
    _ai = _AIConfigFormState.fromAi(widget.template.ai);
  }

  @override
  void dispose() {
    _name.dispose();
    _systemPrompt.dispose();
    _contextMessages.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    // Submit gate: si el provider o modelo seleccionados no están en
    // el catálogo (drift por release del backend), bloqueamos en
    // cliente con copy visible (no se llega a este branch porque el
    // botón también va deshabilitado). Defensa en profundidad.
    if (_isProviderRetired || _isModelRetired) return;
    final contextMessages =
        int.tryParse(_contextMessages.text.trim()) ??
        widget.template.ai.contextMessages;
    final ai = AIConfig(
      enabled: _ai.enabled,
      provider: _ai.provider,
      model: _ai.model,
      temperature: _ai.temperature,
      thinkingLevel: _ai.thinkingLevel,
      systemPrompt: _systemPrompt.text,
      contextMessages: contextMessages,
    );
    context.read<TemplateEditBloc>().add(
      TemplateEditSubmitted(name: name, ai: ai),
    );
  }

  bool get _isProviderRetired =>
      catalogProvider(widget.catalog, _ai.provider.toWire()) == null;

  bool get _isModelRetired =>
      catalogModel(widget.catalog, _ai.provider.toWire(), _ai.model) == null;

  /// Modelo actual en el catálogo, o `null` si retirado/inexistente. Las
  /// flags `supportsTemperature` y `supportsThinking` deciden qué controles
  /// renderea el form — modelos como GPT-5 (razonamiento puro) rechazan
  /// temperatura no-default; MiniMax/DeepSeek razonan nativos sin perilla.
  AIModel? get _currentModel =>
      catalogModel(widget.catalog, _ai.provider.toWire(), _ai.model);

  /// Cambia el provider del state y auto-selecciona el `defaultModel` del
  /// catálogo del nuevo provider. El modelo previo casi nunca existe en
  /// el catálogo del nuevo proveedor (IDs son específicos por vendor);
  /// dejarlo apuntando al modelo viejo lo marcaría como "Retirado" tras
  /// un cambio voluntario, que confunde la causa raíz.
  void _changeProvider(AIProvider next) {
    final entry = catalogProvider(widget.catalog, next.toWire());
    final nextModel = entry?.defaultModel ?? _ai.model;
    setState(() => _ai = _ai.copyWith(provider: next, model: nextModel));
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.submitting;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6 + context.safeBottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            key: const Key('template_edit.field.name'),
            label: 'Nombre de la plantilla',
            hint: 'Ej. Soporte ventas',
            controller: _name,
            enabled: !disabled,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppTokens.sp4),
          AppTextField(
            key: const Key('template_edit.field.system_prompt'),
            label: 'Instrucción del sistema',
            hint: 'Define el rol y el tono del asistente…',
            controller: _systemPrompt,
            enabled: !disabled,
            minLines: 4,
            maxLines: 12,
          ),
          const SizedBox(height: AppTokens.sp6),
          const _SectionHeader(label: 'Configuración IA'),
          const SizedBox(height: AppTokens.sp4),
          _EnabledField(
            value: _ai.enabled,
            enabled: !disabled,
            onChanged: (v) => setState(() => _ai = _ai.copyWith(enabled: v)),
          ),
          const SizedBox(height: AppTokens.sp4),
          _ProviderField(
            value: _ai.provider,
            catalog: widget.catalog,
            enabled: !disabled,
            onChanged: _changeProvider,
          ),
          if (_isProviderRetired) ...<Widget>[
            const SizedBox(height: AppTokens.sp2),
            const _DriftWarning(
              keyValue: 'template_edit.drift.provider_retired',
              copy:
                  'El proveedor guardado ya no está disponible. Elige uno '
                  'del catálogo antes de guardar.',
            ),
          ],
          const SizedBox(height: AppTokens.sp4),
          _ModelField(
            value: _ai.model,
            provider: _ai.provider,
            catalog: widget.catalog,
            enabled: !disabled,
            onChanged: (m) => setState(() => _ai = _ai.copyWith(model: m)),
          ),
          if (!_isProviderRetired && _isModelRetired) ...<Widget>[
            const SizedBox(height: AppTokens.sp2),
            const _DriftWarning(
              keyValue: 'template_edit.drift.model_retired',
              copy:
                  'El modelo guardado ya no está disponible. Elige uno del '
                  'catálogo antes de guardar.',
            ),
          ],
          // Visibility por flag del modelo actual: el slider/dropdown
          // se ocultan si el modelo no soporta el parámetro. El valor
          // del state se PRESERVA aunque el control esté escondido —
          // volver a un modelo que sí lo soporta restaura la tuning
          // del operador sin que tenga que re-introducirla.
          if (_currentModel?.supportsTemperature ?? true) ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            _TemperatureField(
              value: _ai.temperature,
              enabled: !disabled,
              onChanged: (t) =>
                  setState(() => _ai = _ai.copyWith(temperature: t)),
            ),
          ],
          if (_currentModel?.supportsThinking ?? true) ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            _ThinkingField(
              value: _ai.thinkingLevel,
              enabled: !disabled,
              onChanged: (l) =>
                  setState(() => _ai = _ai.copyWith(thinkingLevel: l)),
            ),
          ],
          const SizedBox(height: AppTokens.sp4),
          AppTextField(
            key: const Key('template_edit.field.context_messages'),
            label: 'Mensajes de contexto',
            hint: 'Cuántos turnos previos enviar al modelo',
            controller: _contextMessages,
            enabled: !disabled,
            textInputAction: TextInputAction.done,
            // Teclado numérico (control suave) + formatter digits-only (red
            // de seguridad ante paste, teclado físico o swipe-input). Sin
            // esto, el `int.tryParse(...) ?? template.ai.contextMessages`
            // del submit se tragaba input no numérico al valor original y
            // el operador no entendía por qué no se guardó su edición.
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          const SizedBox(height: AppTokens.sp6),
          AppButton.filled(
            key: const Key('template_edit.submit'),
            label: 'Guardar',
            // Submit gate ante drift: el operador NO puede subir un
            // template con provider/modelo retirado del catálogo. El
            // backend probablemente lo rechazaría con 422, pero
            // bloquearlo en cliente con copy específico es mejor UX.
            onPressed: (_isProviderRetired || _isModelRetired) ? null : _submit,
            loading: widget.submitting,
          ),
          if (widget.submitFailure != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            _SubmitFailedView(failure: widget.submitFailure!),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(color: AppTokens.text1),
  );
}

class _EnabledField extends StatelessWidget {
  const _EnabledField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Activar IA',
                style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
              ),
              const SizedBox(height: AppTokens.sp1),
              Text(
                'El operador decide si los bots con esta plantilla usan IA.',
                style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
              ),
            ],
          ),
        ),
        AppSwitch(
          key: const Key('template_edit.field.enabled'),
          value: value,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _ProviderField extends StatelessWidget {
  const _ProviderField({
    required this.value,
    required this.catalog,
    required this.enabled,
    required this.onChanged,
  });

  final AIProvider value;
  final Catalog catalog;
  final bool enabled;
  final ValueChanged<AIProvider> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // El catálogo expone providers como String del wire; el cliente los
    // proyecta al enum cerrado AIProvider. Un provider del wire que no
    // mapee a la enum se omite del dropdown (fail-loud futuro: si el
    // backend agrega un provider antes que el cliente lo conozca, no
    // aparece — el cliente debe actualizarse).
    final items = <AIProvider>[];
    for (final entry in catalog.providers) {
      try {
        items.add(AIProvider.fromWire(entry.provider));
      } on ArgumentError {
        // Provider del wire desconocido por el cliente.
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Proveedor',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        DropdownButtonFormField<AIProvider>(
          key: const Key('template_edit.field.provider'),
          initialValue: items.contains(value) ? value : null,
          onChanged: enabled
              ? (v) {
                  if (v != null) onChanged(v);
                }
              : null,
          items: items
              .map(
                (p) => DropdownMenuItem<AIProvider>(
                  value: p,
                  // Label humano del DS; el value sigue siendo la enum wire.
                  child: Text(ProviderBadge.labelOf(p)),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _ModelField extends StatelessWidget {
  const _ModelField({
    required this.value,
    required this.provider,
    required this.catalog,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final AIProvider provider;
  final Catalog catalog;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final providerWire = provider.toWire();
    final entry = catalogProvider(catalog, providerWire);
    final modelIds =
        entry?.models.map((m) => m.id).toList(growable: false) ??
        const <String>[];
    // Si el modelo actual no está en el catálogo (drift), lo añadimos
    // como item disabled con label "Retirado:" para que el dropdown
    // pueda renderearse con el value actual. El warning visible vive
    // afuera del dropdown.
    final retired = !modelIds.contains(value) && value.isNotEmpty;
    final items = <DropdownMenuItem<String>>[
      if (retired)
        DropdownMenuItem<String>(
          value: value,
          enabled: false,
          child: Text('Retirado: $value'),
        ),
      ...modelIds.map(
        (id) => DropdownMenuItem<String>(value: id, child: Text(id)),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Modelo',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        DropdownButtonFormField<String>(
          key: const Key('template_edit.field.model'),
          initialValue: items.any((m) => m.value == value) ? value : null,
          onChanged: enabled
              ? (v) {
                  if (v != null) onChanged(v);
                }
              : null,
          items: items,
        ),
      ],
    );
  }
}

class _DriftWarning extends StatelessWidget {
  const _DriftWarning({required this.keyValue, required this.copy});

  final String keyValue;
  final String copy;

  @override
  Widget build(BuildContext context) {
    return Text(
      copy,
      key: Key(keyValue),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppTokens.danger),
    );
  }
}

class _TemperatureField extends StatelessWidget {
  const _TemperatureField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Temperatura',
                style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
              ),
            ),
            Text(
              value.toStringAsFixed(2),
              style: textTheme.labelSmall?.copyWith(color: AppTokens.text1),
            ),
          ],
        ),
        Slider(
          key: const Key('template_edit.field.temperature'),
          value: value.clamp(0.0, 2.0),
          min: 0.0,
          max: 2.0,
          divisions: 40,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _ThinkingField extends StatelessWidget {
  const _ThinkingField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final ThinkingLevel value;
  final bool enabled;
  final ValueChanged<ThinkingLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Nivel de razonamiento',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        DropdownButtonFormField<ThinkingLevel>(
          key: const Key('template_edit.field.thinking'),
          initialValue: value,
          onChanged: enabled
              ? (v) {
                  if (v != null) onChanged(v);
                }
              : null,
          items: ThinkingLevel.values
              .map(
                (l) => DropdownMenuItem<ThinkingLevel>(
                  value: l,
                  child: Text(l.toWire()),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _SubmitFailedView extends StatelessWidget {
  const _SubmitFailedView({required this.failure});

  final TemplatesFailure failure;

  @override
  Widget build(BuildContext context) {
    final (key, copy) = _resolve(failure);
    return Text(
      copy,
      key: Key(key),
      style: const TextStyle(color: AppTokens.danger),
    );
  }

  static (String key, String copy) _resolve(TemplatesFailure f) => switch (f) {
    TemplatesConflictFailure() => (
      'template_edit.error.conflict',
      'Esta plantilla fue editada en otro lugar. Recarga para ver la '
          'versión actual antes de guardar.',
    ),
    TemplatesInvalidUpdateFailure() => (
      'template_edit.error.invalid',
      'Revisa los datos: alguno no cumple las reglas de validación.',
    ),
    TemplatesForbiddenFailure() => (
      'template_edit.error.forbidden',
      'Tu rol no permite editar plantillas. Pide acceso a un admin.',
    ),
    TemplatesNetworkFailure() || TemplatesTimeoutFailure() => (
      'template_edit.error.network',
      'Sin conexión con el servidor. Revisa tu red y reintenta.',
    ),
    TemplatesNotFoundFailure() ||
    TemplatesInvalidNameFailure() ||
    TemplatesServerFailure() ||
    UnknownTemplatesFailure() => (
      'template_edit.error.generic',
      'No pudimos guardar los cambios. Inténtalo de nuevo.',
    ),
  };
}
