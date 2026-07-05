import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/variable_def.dart';
import '../bloc/var_defs_bloc.dart';
import '../widgets/var_def_form_sheet.dart';

/// Variables (var-defs) de una plantilla (`/templates/:id/variables`), con
/// buscador local y tarjetas ricas ({{name}} + default + descripción).
/// Posee su Scaffold — AppBar y FAB [+] de crear — como las páginas del
/// entrenador; la ruta solo provee el VarDefsBloc. El FAB se oculta durante
/// una mutación (el sheet abierto ya tiene su propio submit).
class TemplateVariablesPage extends StatefulWidget {
  const TemplateVariablesPage({super.key});

  @override
  State<TemplateVariablesPage> createState() => _TemplateVariablesPageState();
}

class _TemplateVariablesPageState extends State<TemplateVariablesPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _query => _search.text.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    return BlocListener<VarDefsBloc, VarDefsState>(
      // Feedback de mutación fallida. El sheet sigue montado tras una
      // MutationFailed (operador corrige y reintenta); el snackbar
      // verbaliza el fallo sin tirar contexto.
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
      child: BlocBuilder<VarDefsBloc, VarDefsState>(
        builder: (context, state) {
          // El FAB solo existe cuando hay snapshot estable para abrir el
          // sheet (existingNames sale de las defs actuales).
          final fabDefs = switch (state) {
            VarDefsLoaded(defs: final d) => d,
            VarDefsMutationFailed(defs: final d) => d,
            _ => null,
          };
          return Scaffold(
            appBar: AppBar(title: const Text('Variables')),
            floatingActionButton: fabDefs == null
                ? null
                : FloatingActionButton(
                    key: const Key('template_variables.fab'),
                    tooltip: 'Agregar variable',
                    onPressed: () => _openSheet(context, fabDefs),
                    child: const Icon(Icons.add),
                  ),
            body: switch (state) {
              VarDefsLoading() => const Center(
                key: Key('var_defs.loading'),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
                ),
              ),
              VarDefsLoaded(defs: final defs) => _content(context, defs),
              VarDefsMutating(defs: final defs) => _content(context, defs),
              VarDefsMutationFailed(defs: final defs) => _content(
                context,
                defs,
              ),
              VarDefsFailed() => const _FailedView(),
            },
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, List<VariableDef> all) {
    final q = _query;
    final filtered = q.isEmpty
        ? all
        : all
              .where((d) => d.name.toLowerCase().contains(q))
              .toList(growable: false);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp4,
        AppTokens.sp6,
        // Espacio extra al fondo para que el FAB no tape la última tarjeta.
        AppTokens.sp9 + context.safeBottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (all.isNotEmpty) ...<Widget>[
            AppTextField(
              key: const Key('template_variables.search'),
              label: 'Buscar',
              hint: 'Nombre de la variable',
              controller: _search,
            ),
            const SizedBox(height: AppTokens.sp4),
          ],
          if (all.isEmpty)
            Text(
              'Esta plantilla aún no tiene variables.',
              key: const Key('var_defs.empty'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppTokens.text2,
              ),
            )
          else if (filtered.isEmpty)
            Text(
              'Sin resultados para "${_search.text.trim()}".',
              key: const Key('template_variables.no_results'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppTokens.text2,
              ),
            )
          else
            for (final d in filtered)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.cardGap),
                child: _VarDefCard(
                  def: d,
                  onTap: () => _openSheet(context, all, editing: d),
                ),
              ),
        ],
      ),
    );
  }

  /// Monta el sheet de creación o edición. El sheet vive sobre el bloc del
  /// scope; `.value` le pasa la misma instancia (el modal crea un context
  /// que no hereda los BlocProviders del padre por default).
  void _openSheet(
    BuildContext context,
    List<VariableDef> defs, {
    VariableDef? editing,
  }) {
    final bloc = context.read<VarDefsBloc>();
    showAppBottomSheet<void>(
      context,
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

/// Tarjeta rica de una variable: glifo + `{{name}}` + default + descripción
/// + borrar. Tap → sheet de edición.
class _VarDefCard extends StatelessWidget {
  const _VarDefCard({required this.def, required this.onTap});

  final VariableDef def;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      key: Key('var_defs.row.${def.id}'),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          const AppEntityIcon(icon: Icons.data_object),
          const SizedBox(width: AppTokens.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // El placeholder `{{name}}` es como el operador referencia
                // la variable desde el prompt; más útil que el name pelado.
                Text(
                  '{{${def.name}}}',
                  style: t.titleMedium?.copyWith(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 2),
                Text(
                  def.defaultValue.isEmpty ? '—' : def.defaultValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(
                    color: def.defaultValue.isEmpty ? AppTokens.text2 : null,
                  ),
                ),
                if (def.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      def.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(color: AppTokens.text2),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            key: Key('var_defs.row.${def.id}.delete'),
            icon: const Icon(Icons.delete_outline, color: AppTokens.danger),
            tooltip: 'Eliminar variable',
            onPressed: () => _confirmDelete(context, def),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, VariableDef def) async {
    final bloc = context.read<VarDefsBloc>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Eliminar variable',
      message:
          '¿Eliminar la variable {{${def.name}}}? '
          'Los bots que ya tengan un valor asignado bloquearán esta acción.',
      confirmLabel: 'Eliminar',
      confirmKey: const Key('var_defs.delete_confirm'),
    );
    if (confirmed) {
      bloc.add(VarDefsDeleteRequested(varDefId: def.id));
    }
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.sp6),
      child: Row(
        key: const Key('var_defs.failed'),
        children: <Widget>[
          Expanded(
            child: Text(
              'No pudimos cargar las variables.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
            ),
          ),
          AppButton.text(
            label: 'Reintentar',
            onPressed: () =>
                context.read<VarDefsBloc>().add(const VarDefsLoadRequested()),
          ),
        ],
      ),
    );
  }
}
