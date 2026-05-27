import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/provider_badge.dart';
import '../../../flows/domain/entities/flow.dart' as fdom;
import '../../../flows/presentation/bloc/flows_bloc.dart';
import '../../../triggers/presentation/widgets/triggers_section.dart';
import '../../domain/entities/template.dart';
import '../../domain/entities/variable_def.dart';
import '../../domain/failures/templates_failure.dart';
import '../bloc/template_detail_bloc.dart';
import '../bloc/var_defs_bloc.dart';
import '../widgets/var_def_form_sheet.dart';

/// Detalle de una Template (S03). Consume el `TemplateDetailBloc` del scope;
/// el cableado del provider y del ID lo hace el router en `/templates/:id`.
/// Es content-only: el Scaffold y el AppBar los aporta la ruta.
class TemplateDetailPage extends StatelessWidget {
  const TemplateDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<VarDefsBloc, VarDefsState>(
      // Feedback global de mutaciones de var-defs. El sheet sigue
      // montado tras una MutationFailed (operador corrige y reintenta);
      // el snackbar verbalízale el fallo sin tirar contexto.
      listener: (context, state) {
        if (state is VarDefsMutationFailed) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'La plantilla cambió. Recarga para ver los últimos datos.',
                ),
              ),
            );
        }
      },
      child: BlocBuilder<TemplateDetailBloc, TemplateDetailState>(
        builder: (context, state) => switch (state) {
          TemplateDetailLoading() => const _LoadingView(),
          TemplateDetailLoaded(template: final tpl) => _LoadedView(
            template: tpl,
          ),
          TemplateDetailFailed(failure: final f) => _FailedView(failure: f),
        },
      ),
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

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    final ai = template.ai;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6 + context.safeBottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppCard(
            key: const Key('template_detail.card.header'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    AppAvatar(name: template.name, size: 64),
                    const SizedBox(width: AppTokens.sp4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(template.name, style: textTheme.titleLarge),
                          const SizedBox(height: 2),
                          ProviderBadge(provider: ai.provider),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.sp4),
                Wrap(
                  spacing: AppTokens.sp2,
                  runSpacing: AppTokens.sp2,
                  children: <Widget>[
                    AppPill.outline(label: 'v${template.version}'),
                    // IA on/off es estado de configuración, no error: primary
                    // cuando está habilitada, neutral cuando no — danger queda
                    // reservado para fallos reales (load errors, destructive).
                    if (ai.enabled)
                      const AppPill.primary(
                        label: 'IA habilitada',
                        dot: AppPillDot.active,
                      )
                    else
                      const AppPill.neutral(
                        label: 'IA deshabilitada',
                        dot: AppPillDot.paused,
                      ),
                  ],
                ),
                const SizedBox(height: AppTokens.sp5),
                _EditButton(template: template),
                const SizedBox(height: AppTokens.sp3),
                _CreateBotButton(template: template),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.sp6),
          AppCard(
            key: const Key('template_detail.card.flows'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Flujos'),
                const SizedBox(height: AppTokens.sp3),
                _FlowsSection(templateId: template.id),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.sp6),
          const AppCard(
            key: Key('template_detail.card.triggers'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SectionTitle('Disparadores'),
                SizedBox(height: AppTokens.sp3),
                TriggersSection(),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.sp6),
          const AppCard(
            key: Key('template_detail.card.variables'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SectionTitle('Variables'),
                SizedBox(height: AppTokens.sp3),
                _VarDefsSection(),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.sp6),
          AppCard(
            key: const Key('template_detail.card.ai_config'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Configuración IA'),
                const SizedBox(height: AppTokens.sp3),
                _StatGrid(ai: ai),
                const SizedBox(height: AppTokens.sp5),
                const _SectionTitle('Prompt del sistema'),
                const SizedBox(height: AppTokens.sp2),
                if (ai.systemPrompt.isEmpty)
                  Text(
                    'Sin prompt definido',
                    style: textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppTokens.text2,
                    ),
                  )
                else
                  SelectableText(ai.systemPrompt, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(color: AppTokens.text2),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.ai});

  final AIConfig ai;

  @override
  Widget build(BuildContext context) {
    // 2×2 stats — la sección Motor IA cabe en una grilla compacta en
    // mobile sin scroll horizontal y deja respirar el system prompt
    // debajo. IntrinsicHeight iguala la altura de las dos cards de cada
    // fila cuando un modelo largo (p.ej. 'gemini-3.1-pro-preview')
    // estira una columna pero no la otra.
    return Column(
      children: <Widget>[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _StatTile(label: 'Modelo', value: ai.model),
              ),
              const SizedBox(width: AppTokens.cardGap),
              Expanded(
                child: _StatTile(
                  label: 'Temperatura',
                  value: ai.temperature.toStringAsFixed(1),
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
                  label: 'Razonamiento',
                  value: _thinkingLabel(ai.thinkingLevel),
                ),
              ),
              const SizedBox(width: AppTokens.cardGap),
              Expanded(
                child: _StatTile(
                  label: 'Mensajes de contexto',
                  value: ai.contextMessages.toString(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _thinkingLabel(ThinkingLevel t) => switch (t) {
    ThinkingLevel.low => 'Bajo',
    ThinkingLevel.medium => 'Medio',
    ThinkingLevel.high => 'Alto',
  };
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Tile plano (no AppCard) — vive dentro de la AppCard outer de
    // Configuración IA, así que se diferencia visualmente con surface3
    // sobre el surface2 de la card padre, sin doble shell.
    return Container(
      padding: const EdgeInsets.all(AppTokens.sp4),
      decoration: BoxDecoration(
        color: AppTokens.surface3,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: textTheme.labelSmall),
          const SizedBox(height: AppTokens.sp1),
          Text(value, style: textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _VarDefsSection extends StatelessWidget {
  const _VarDefsSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VarDefsBloc, VarDefsState>(
      builder: (context, state) => switch (state) {
        VarDefsLoading() => const Padding(
          key: Key('var_defs.loading'),
          padding: EdgeInsets.symmetric(vertical: AppTokens.sp2),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        VarDefsLoaded(defs: final defs) => _VarDefsList(
          defs: defs,
          showAddButton: true,
        ),
        // Durante una mutación seguimos mostrando el snapshot previo;
        // el botón de Agregar se oculta para no permitir doble dispatch
        // mientras el sheet ya está abierto con su propio submit.
        VarDefsMutating(defs: final defs) => _VarDefsList(
          defs: defs,
          showAddButton: false,
        ),
        // MutationFailed: lista intacta y botón visible para reintentar.
        VarDefsMutationFailed(defs: final defs) => _VarDefsList(
          defs: defs,
          showAddButton: true,
        ),
        VarDefsFailed() => const _VarDefsFailedView(),
      },
    );
  }
}

class _VarDefsList extends StatelessWidget {
  const _VarDefsList({required this.defs, required this.showAddButton});

  final List<VariableDef> defs;
  final bool showAddButton;

  @override
  Widget build(BuildContext context) {
    final empty = defs.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (empty)
          Text(
            'Esta plantilla aún no tiene variables.',
            key: const Key('var_defs.empty'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: AppTokens.text2,
            ),
          )
        else
          for (final d in defs)
            _VarDefRow(
              def: d,
              onTap: () => _openSheet(context, defs, editing: d),
            ),
        if (showAddButton) ...<Widget>[
          const SizedBox(height: AppTokens.sp3),
          AppButton.text(
            key: const Key('var_defs.add_button'),
            label: 'Agregar variable',
            icon: Icons.add,
            onPressed: () => _openSheet(context, defs),
          ),
        ],
      ],
    );
  }

  /// Monta el sheet de creación o edición. El sheet vive sobre el bloc
  /// del detail page; usamos `.value` para pasarle la misma instancia
  /// (el modal crea un nuevo context que no hereda de los
  /// BlocProviders del padre por default).
  void _openSheet(
    BuildContext context,
    List<VariableDef> defs, {
    VariableDef? editing,
  }) {
    final bloc = context.read<VarDefsBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider<VarDefsBloc>.value(
        value: bloc,
        child: VarDefFormSheet(
          existingNames: defs.map((d) => d.name).toSet(),
          editing: editing,
        ),
      ),
    );
  }
}

class _VarDefRow extends StatelessWidget {
  const _VarDefRow({required this.def, required this.onTap});

  final VariableDef def;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      key: Key('var_defs.row.${def.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusField),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 180,
                        // El placeholder de interpolación `{{name}}` es la
                        // forma en que el operador referencia la variable
                        // desde el prompt; mostrarla así es más útil que el
                        // name pelado. No usamos SelectableText: el row es
                        // tap-target del edit sheet y el gesture detector
                        // interno del Selectable ganaría el tap. La copia
                        // puede agregarse via long-press menu en un slice
                        // futuro si se pide.
                        child: Text(
                          '{{${def.name}}}',
                          style: t.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          def.defaultValue.isEmpty ? '—' : def.defaultValue,
                          style: t.bodyMedium?.copyWith(
                            color: def.defaultValue.isEmpty
                                ? AppTokens.text2
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_typePillLabel(def.type) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: AppPill.neutral(
                        key: Key('var_defs.row.${def.id}.type_pill'),
                        label: _typePillLabel(def.type)!,
                      ),
                    ),
                  if (def.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        def.description,
                        style: t.bodySmall?.copyWith(color: AppTokens.text2),
                      ),
                    ),
                ],
              ),
            ),
            // Trash icon como acción destructiva. Tap apunta y abre
            // confirm dialog — no compite con el tap del row (InkWell
            // padre) porque el IconButton tiene su propio gesture detector
            // y "absorbe" su área (Flutter usa hit-testing por proximidad).
            IconButton(
              key: Key('var_defs.row.${def.id}.delete'),
              icon: const Icon(Icons.delete_outline, color: AppTokens.danger),
              tooltip: 'Eliminar variable',
              onPressed: () => _confirmDelete(context, def),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, VariableDef def) async {
    final bloc = context.read<VarDefsBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('var_defs.delete_confirm'),
        title: const Text('Eliminar variable'),
        content: Text(
          '¿Eliminar la variable {{${def.name}}}? '
          'Los bots que ya tengan un valor asignado bloquearán esta acción.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppTokens.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(VarDefsDeleteRequested(varDefId: def.id));
    }
  }
}

class _VarDefsFailedView extends StatelessWidget {
  const _VarDefsFailedView();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('var_defs.failed'),
      children: <Widget>[
        const Expanded(
          child: Text(
            'No pudimos cargar las variables.',
            style: TextStyle(color: AppTokens.danger),
          ),
        ),
        AppButton.text(
          label: 'Reintentar',
          onPressed: () =>
              context.read<VarDefsBloc>().add(const VarDefsLoadRequested()),
        ),
      ],
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    return AppButton.tonal(
      key: const Key('template_detail.edit_button'),
      label: 'Editar plantilla',
      icon: Icons.edit_outlined,
      onPressed: () {
        // push apila el editor sobre el detalle; el back físico vuelve al
        // detalle (no sale de la app, no aplasta pila).
        context.push('/templates/${template.id}/edit');
      },
    );
  }
}

class _CreateBotButton extends StatelessWidget {
  const _CreateBotButton({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    return AppButton.filled(
      key: const Key('template_detail.create_bot_button'),
      label: 'Crear bot',
      icon: Icons.smart_toy_outlined,
      onPressed: () {
        // El nombre viaja como query param URL-encoded para que el form
        // pueda mostrar el chip de plantilla sin pedirla otra vez al
        // backend. push (no go) apila el form sobre el shell + detalle,
        // así el back físico de Android vuelve a este detalle.
        final name = Uri.encodeQueryComponent(template.name);
        context.push('/templates/${template.id}/bots/new?name=$name');
      },
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final TemplatesFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is TemplatesNotFoundFailure;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: isNotFound
          ? const Key('template_detail.error.not_found')
          : const Key('template_detail.error.generic'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              isNotFound
                  ? 'Esta plantilla ya no existe en tu organización'
                  : 'No pudimos cargar el detalle de la plantilla',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
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

/// Label humanizado para la pill del tipo en el row de variables. `null` ⇒
/// no pintar pill (text es el default semántico del producto y se asume
/// cuando no hay marcado visible).
String? _typePillLabel(VarType t) => switch (t) {
  VarType.text => null,
  VarType.label => 'Etiqueta',
  VarType.image => 'Imagen',
  VarType.video => 'Video',
  VarType.audio => 'Audio',
  VarType.document => 'Documento',
};

// ── Sección Flujos (S11 F1, read-only) ───────────────────────────────────────

class _FlowsSection extends StatelessWidget {
  const _FlowsSection({required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlowsBloc, FlowsState>(
      builder: (context, state) => switch (state) {
        FlowsLoading() => const Padding(
          key: Key('flows.loading'),
          padding: EdgeInsets.symmetric(vertical: AppTokens.sp2),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        FlowsLoaded(flows: final fs) => _FlowsList(
          items: fs,
          templateId: templateId,
        ),
        FlowsFailed() => const _FlowsFailedView(),
      },
    );
  }
}

class _FlowsList extends StatelessWidget {
  const _FlowsList({required this.items, required this.templateId});

  final List<fdom.Flow> items;
  final String templateId;

  @override
  Widget build(BuildContext context) {
    final empty = items.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (empty)
          Text(
            'Esta plantilla aún no tiene flujos.',
            key: const Key('flows.empty'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: AppTokens.text2,
            ),
          )
        else
          for (final f in items) _FlowRow(flow: f),
        const SizedBox(height: AppTokens.sp3),
        AppButton.text(
          key: const Key('flows.add_button'),
          label: 'Nuevo flujo',
          icon: Icons.add,
          // push apila el form sobre el detalle; back físico vuelve aquí
          // sin pasar por el form que ya cumplió (Succeeded usa
          // pushReplacement a /flows/:id).
          onPressed: () => context.push('/templates/$templateId/flows/new'),
        ),
      ],
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({required this.flow});

  final fdom.Flow flow;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      key: Key('flows.row.${flow.id}'),
      // push apila el editor del flow sobre el detalle de plantilla; el
      // back físico vuelve al detalle. La ruta /flows/:id la monta el
      // slice del editor de flujos.
      onTap: () => context.push('/flows/${flow.id}'),
      borderRadius: BorderRadius.circular(AppTokens.radiusField),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: Text(flow.name, style: t.bodyMedium)),
            if (flow.isActive)
              AppPill.primary(
                key: Key('flows.row.${flow.id}.status_pill'),
                label: 'Activo',
                dot: AppPillDot.active,
              )
            else
              AppPill.neutral(
                key: Key('flows.row.${flow.id}.status_pill'),
                label: 'Pausado',
                dot: AppPillDot.paused,
              ),
          ],
        ),
      ),
    );
  }
}

class _FlowsFailedView extends StatelessWidget {
  const _FlowsFailedView();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('flows.failed'),
      children: <Widget>[
        const Expanded(
          child: Text(
            'No pudimos cargar los flujos.',
            style: TextStyle(color: AppTokens.danger),
          ),
        ),
        AppButton.text(
          label: 'Reintentar',
          onPressed: () =>
              context.read<FlowsBloc>().add(const FlowsLoadRequested()),
        ),
      ],
    );
  }
}
