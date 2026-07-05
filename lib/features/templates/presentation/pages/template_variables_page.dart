import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/variable_def.dart';
import '../bloc/var_defs_bloc.dart';
import '../widgets/var_def_form_sheet.dart';

/// Variables (var-defs) de una plantilla (`/templates/:id/variables`), con
/// buscador local y lista densa: UNA card apila las filas (una por variable,
/// {{name}} + default + descripción) separadas por divider hairline. Posee su
/// Scaffold — AppBar y FAB [+] de crear — como las páginas del entrenador; la
/// ruta solo provee el VarDefsBloc. El FAB se oculta durante una mutación (el
/// sheet abierto ya tiene su propio submit).
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
              VarDefsLoading() => const AppLoadingIndicator(
                key: Key('var_defs.loading'),
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
      key: const Key('template_variables.content'),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp4,
        AppTokens.sp6,
        // fabClearance: la última fila debe poder quedar por encima del FAB
        // de crear que flota sobre esta página.
        AppTokens.fabClearance + context.safeBottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Sin variables no hay nada que filtrar: el buscador solo aparece
          // cuando existe una lista que recortar.
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
            _VarDefsCard(
              defs: filtered,
              // El sheet valida contra TODOS los nombres, no solo los
              // filtrados: renombrar hacia un duplicado oculto por el
              // buscador debe seguir bloqueado.
              onEdit: (d) => _openSheet(context, all, editing: d),
            ),
        ],
      ),
    );
  }

  /// Monta el sheet de creación o edición; `VarDefFormSheet.open` re-provee
  /// el bloc del scope y aplica el fondo canónico.
  void _openSheet(
    BuildContext context,
    List<VariableDef> defs, {
    VariableDef? editing,
  }) {
    VarDefFormSheet.open(
      context,
      existingNames: defs.map((d) => d.name).toSet(),
      editing: editing,
    );
  }
}

/// El listado como UNA card que apila las filas de variables separadas por
/// divider hairline (idioma de los hubs y de las listas de bots/plantillas),
/// en lugar de una card suelta por item.
class _VarDefsCard extends StatelessWidget {
  const _VarDefsCard({required this.defs, required this.onEdit});

  final List<VariableDef> defs;
  final ValueChanged<VariableDef> onEdit;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < defs.length; i++) {
      if (i > 0) {
        rows.add(
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
        );
      }
      final d = defs[i];
      rows.add(_VarDefTile(def: d, onTap: () => onEdit(d)));
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}

/// Fila de una variable dentro de la card del listado: glifo + `{{name}}` +
/// default + descripción + borrar. Tap → sheet de edición.
///
/// Toda la fila es tap-target hacia el sheet; el InkWell propio da el ripple
/// (la card contenedora no es tappable).
class _VarDefTile extends StatelessWidget {
  const _VarDefTile({required this.def, required this.onTap});

  final VariableDef def;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      key: Key('var_defs.row.${def.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
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
            // Trash icon como acción destructiva. Su propio gesture detector
            // absorbe el tap y no compite con el onTap de la fila.
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

/// Fallo de carga como estado canónico del kit: card sobria con la copy del
/// problema y reintento que re-dispatcha el load.
class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.sp6),
      child: AppErrorState(
        key: const Key('var_defs.failed'),
        message: 'No pudimos cargar las variables.',
        onRetry: () =>
            context.read<VarDefsBloc>().add(const VarDefsLoadRequested()),
      ),
    );
  }
}
