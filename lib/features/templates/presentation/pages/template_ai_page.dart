import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_switch.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../ai_catalog/domain/entities/catalog.dart';
import '../../../ai_catalog/presentation/bloc/catalog_bloc.dart';
import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../bloc/template_detail_bloc.dart';
import '../widgets/thinking_label.dart';

/// Motor IA de una plantilla (`/templates/:id/ai`): información Y edición en
/// la misma superficie. Cada stat tile es tappable y abre un control
/// enfocado (picker del catálogo, slider, choices, número); el switch de
/// IA habilitada muta directo. Cada edición es un PUT con CAS sobre el
/// `TemplateDetailBloc` (re-GET en 409); el name nunca viaja modificado.
///
/// El catálogo gobierna capacidades: un modelo sin `supportsTemperature` /
/// `supportsThinking` deja su tile como solo-lectura ("Fija del modelo").
/// El prompt se LEE aquí (completo, seleccionable); se EDITA conversando
/// con el Entrenador — el CTA del pie lo lleva ahí.
class TemplateAiPage extends StatelessWidget {
  const TemplateAiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<TemplateDetailBloc, TemplateDetailState>(
      listener: (context, state) {
        if (state is TemplateDetailMutationFailed) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(content: Text(_failureCopy(state.failure))),
            );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Motor IA')),
        body: BlocBuilder<TemplateDetailBloc, TemplateDetailState>(
          builder: (context, state) => switch (state) {
            TemplateDetailLoading() => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
              ),
            ),
            TemplateDetailLoaded(template: final tpl) => _LoadedView(
              template: tpl,
              isMutating: false,
            ),
            TemplateDetailMutating(template: final tpl) => _LoadedView(
              template: tpl,
              isMutating: true,
            ),
            TemplateDetailMutationFailed(template: final tpl) => _LoadedView(
              template: tpl,
              isMutating: false,
            ),
            TemplateDetailFailed() => const _FailedView(),
          },
        ),
      ),
    );
  }

  static String _failureCopy(TemplatesFailure f) => switch (f) {
    TemplatesConflictFailure() =>
      'Tu edición estaba desactualizada; la refrescamos. Reintenta.',
    TemplatesInvalidUpdateFailure() => 'El valor no es válido para el motor.',
    TemplatesForbiddenFailure() => 'Tu rol no permite editar esta plantilla.',
    _ => 'No pudimos guardar el cambio. Inténtalo de nuevo.',
  };
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.template, required this.isMutating});

  final Template template;

  /// PUT en vuelo: los controles quedan inertes (sin doble dispatch).
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    final ai = template.ai;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp4,
        AppTokens.sp6,
        AppTokens.sp6 + context.safeBottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _EnabledRow(ai: ai, isMutating: isMutating),
          const SizedBox(height: AppTokens.sp5),
          BlocBuilder<CatalogBloc, CatalogState>(
            builder: (context, catState) {
              final catalog = catState is CatalogLoaded
                  ? catState.catalog
                  : null;
              return _StatGrid(
                ai: ai,
                catalog: catalog,
                isMutating: isMutating,
              );
            },
          ),
          const SizedBox(height: AppTokens.sp6),
          Text(
            'Prompt del sistema',
            style: textTheme.titleMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp3),
          if (ai.systemPrompt.isEmpty)
            Text(
              'Sin prompt definido',
              style: textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppTokens.text2,
              ),
            )
          else
            // El prompt entero, seleccionable para copiar: esta página
            // existe para LEERLO; se edita conversando con el Entrenador.
            SelectableText(ai.systemPrompt, style: textTheme.bodyMedium),
          const SizedBox(height: AppTokens.sp7),
          AppButton.filled(
            key: const Key('template_ai.train_button'),
            label: 'Entrenar prompt',
            icon: Icons.school_outlined,
            fullWidth: true,
            // push apila el entrenador; back físico vuelve a esta ficha.
            onPressed: () => context.push('/templates/${template.id}/trainer'),
          ),
        ],
      ),
    );
  }
}

/// Switch de IA habilitada: muta directo (un campo, un PUT).
class _EnabledRow extends StatelessWidget {
  const _EnabledRow({required this.ai, required this.isMutating});

  final AIConfig ai;
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('IA habilitada', style: textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                'Apagada, los bots de esta plantilla no responden con IA.',
                style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.sp3),
        AppSwitch(
          key: const Key('template_ai.enabled'),
          value: ai.enabled,
          onChanged: isMutating
              ? null
              : (v) => context.read<TemplateDetailBloc>().add(
                  TemplateDetailAiUpdateRequested(ai.copyWith(enabled: v)),
                ),
        ),
      ],
    );
  }
}

/// Grilla 2×2 de tiles información+control. Tappable abre el editor
/// enfocado del campo; un campo no soportado por el modelo queda
/// solo-lectura con la nota "Fija del modelo".
class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.ai,
    required this.catalog,
    required this.isMutating,
  });

  final AIConfig ai;
  final Catalog? catalog;
  final bool isMutating;

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

  @override
  Widget build(BuildContext context) {
    final info = _modelInfo;
    // Sin catálogo (o modelo fuera de tabla) asumimos editable: el backend
    // valida de todas formas; bloquear sería inventar una restricción.
    final canTemperature = info?.supportsTemperature ?? true;
    final canThinking = info?.supportsThinking ?? true;
    return Column(
      children: <Widget>[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _StatTile(
                  tileKey: const Key('template_ai.tile.model'),
                  label: 'Modelo',
                  value: ai.model,
                  // El picker exige catálogo: sin tabla no hay opciones.
                  onTap: isMutating || catalog == null
                      ? null
                      : () => _pickModel(context),
                ),
              ),
              const SizedBox(width: AppTokens.cardGap),
              Expanded(
                child: _StatTile(
                  tileKey: const Key('template_ai.tile.temperature'),
                  label: 'Temperatura',
                  value: ai.temperature.toStringAsFixed(1),
                  note: canTemperature ? null : 'Fija del modelo',
                  onTap: isMutating || !canTemperature
                      ? null
                      : () => _pickTemperature(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.cardGap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _StatTile(
                  tileKey: const Key('template_ai.tile.thinking'),
                  label: 'Razonamiento',
                  value: thinkingLabel(ai.thinkingLevel),
                  note: canThinking ? null : 'Fija del modelo',
                  onTap: isMutating || !canThinking
                      ? null
                      : () => _pickThinking(context),
                ),
              ),
              const SizedBox(width: AppTokens.cardGap),
              Expanded(
                child: _StatTile(
                  tileKey: const Key('template_ai.tile.context'),
                  label: 'Mensajes de contexto',
                  value: ai.contextMessages.toString(),
                  onTap: isMutating ? null : () => _pickContext(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.cardGap),
        _StatTile(
          tileKey: const Key('template_ai.tile.delay'),
          label: 'Retraso de respuesta',
          value: ai.responseDelaySeconds == 0
              ? 'Inmediato'
              : '${ai.responseDelaySeconds}s',
          onTap: isMutating ? null : () => _pickDelay(context),
        ),
      ],
    );
  }

  void _dispatch(BuildContext context, AIConfig next) {
    context.read<TemplateDetailBloc>().add(
      TemplateDetailAiUpdateRequested(next),
    );
  }

  Future<void> _pickModel(BuildContext context) async {
    final cat = catalog;
    if (cat == null) return;
    final bloc = context.read<TemplateDetailBloc>();
    final picked =
        await showModalBottomSheet<({AIProvider provider, String model})>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppTokens.surface1,
          builder: (_) => _ModelSheet(catalog: cat, current: ai.model),
        );
    if (picked == null) return;
    bloc.add(
      TemplateDetailAiUpdateRequested(
        ai.copyWith(provider: picked.provider, model: picked.model),
      ),
    );
  }

  Future<void> _pickTemperature(BuildContext context) async {
    final picked = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: AppTokens.surface1,
      builder: (_) => _TemperatureSheet(initial: ai.temperature),
    );
    if (picked == null || !context.mounted) return;
    _dispatch(context, ai.copyWith(temperature: picked));
  }

  Future<void> _pickThinking(BuildContext context) async {
    final picked = await showModalBottomSheet<ThinkingLevel>(
      context: context,
      backgroundColor: AppTokens.surface1,
      builder: (_) => _ThinkingSheet(current: ai.thinkingLevel),
    );
    if (picked == null || !context.mounted) return;
    _dispatch(context, ai.copyWith(thinkingLevel: picked));
  }

  Future<void> _pickContext(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => _ContextSheet(initial: ai.contextMessages),
    );
    if (picked == null || !context.mounted) return;
    _dispatch(context, ai.copyWith(contextMessages: picked));
  }

  Future<void> _pickDelay(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => _DelaySheet(initial: ai.responseDelaySeconds),
    );
    if (picked == null || !context.mounted) return;
    _dispatch(context, ai.copyWith(responseDelaySeconds: picked));
  }
}

/// Tile información+control: label + valor + lápiz cuando es editable, o
/// nota "Fija del modelo" cuando el modelo no soporta el campo.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.tileKey,
    required this.label,
    required this.value,
    this.note,
    this.onTap,
  });

  final Key tileKey;
  final String label;
  final String value;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: tileKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.sp4),
        decoration: BoxDecoration(
          color: AppTokens.surface2,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(label, style: textTheme.labelSmall)),
                if (onTap != null)
                  const Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: AppTokens.text2,
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.sp1),
            Text(value, style: textTheme.titleMedium),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  note!,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTokens.text2,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Picker de modelo agrupado por proveedor. Tap = elegir y cerrar.
class _ModelSheet extends StatelessWidget {
  const _ModelSheet({required this.catalog, required this.current});

  final Catalog catalog;
  final String current;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('template_ai.sheet.model'),
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
            Text('Modelo', style: textTheme.titleLarge),
            const SizedBox(height: AppTokens.sp4),
            for (final entry in catalog.providers)
              ..._providerSection(context, entry, textTheme),
          ],
        ),
      ),
    );
  }

  List<Widget> _providerSection(
    BuildContext context,
    ProviderEntry entry,
    TextTheme textTheme,
  ) {
    // Un proveedor que este release no reconoce se omite: no podemos
    // construir el AIProvider del PUT (el backend puede ir adelante).
    final AIProvider provider;
    try {
      provider = AIProvider.fromWire(entry.provider);
    } on ArgumentError {
      return const <Widget>[];
    }
    return <Widget>[
      Padding(
        padding: const EdgeInsets.only(
          top: AppTokens.sp3,
          bottom: AppTokens.sp1,
        ),
        child: Text(
          entry.provider,
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
      ),
      for (final m in entry.models)
        InkWell(
          key: Key('template_ai.model.${m.id}'),
          onTap: () =>
              Navigator.of(context).pop((provider: provider, model: m.id)),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppTokens.sp3,
              horizontal: AppTokens.sp1,
            ),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(m.id, style: textTheme.bodyLarge)),
                if (m.id == current)
                  const Icon(Icons.check, color: AppTokens.primary, size: 20),
              ],
            ),
          ),
        ),
    ];
  }
}

/// Slider de temperatura 0.0–2.0 con Guardar explícito.
class _TemperatureSheet extends StatefulWidget {
  const _TemperatureSheet({required this.initial});

  final double initial;

  @override
  State<_TemperatureSheet> createState() => _TemperatureSheetState();
}

class _TemperatureSheetState extends State<_TemperatureSheet> {
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
                  child: Slider(
                    value: _value,
                    min: 0.0,
                    max: 2.0,
                    divisions: 20,
                    activeColor: AppTokens.primary,
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
              key: const Key('template_ai.sheet.temperature.save'),
              label: 'Guardar',
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
class _ThinkingSheet extends StatelessWidget {
  const _ThinkingSheet({required this.current});

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
              InkWell(
                key: Key('template_ai.thinking.${level.name}'),
                onTap: () => Navigator.of(context).pop(level),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTokens.sp3,
                    horizontal: AppTokens.sp1,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          thinkingLabel(level),
                          style: textTheme.bodyLarge,
                        ),
                      ),
                      if (level == current)
                        const Icon(
                          Icons.check,
                          color: AppTokens.primary,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Campo numérico de mensajes de contexto con Guardar explícito.
class _ContextSheet extends StatefulWidget {
  const _ContextSheet({required this.initial});

  final int initial;

  @override
  State<_ContextSheet> createState() => _ContextSheetState();
}

class _ContextSheetState extends State<_ContextSheet> {
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
              key: const Key('template_ai.sheet.context.field'),
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
              key: const Key('template_ai.sheet.context.save'),
              label: 'Guardar',
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

/// Campo numérico de la ventana de acumulación (0..120 s) con Guardar
/// explícito. 0 = responder de inmediato (comportamiento histórico).
class _DelaySheet extends StatefulWidget {
  const _DelaySheet({required this.initial});

  final int initial;

  @override
  State<_DelaySheet> createState() => _DelaySheetState();
}

class _DelaySheetState extends State<_DelaySheet> {
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
              key: const Key('template_ai.sheet.delay.field'),
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
              key: const Key('template_ai.sheet.delay.save'),
              label: 'Guardar',
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

class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No pudimos cargar el motor IA de la plantilla',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<TemplateDetailBloc>().add(
                const TemplateDetailLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
