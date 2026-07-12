import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../templates/domain/entities/variable_def.dart';
import '../../domain/failures/bots_failure.dart';
import '../bloc/bot_variables_bloc.dart';
import '../widgets/bot_variable_card.dart';

/// Editor de `variable_values` de un Bot (S04), sub-página ruteada
/// (`/bots/:id/variables`). Content-only: el Scaffold/AppBar los aporta la ruta.
///
/// PRECARGA los overrides guardados (vía `getVariables`): un campo con override
/// muestra su valor; uno sin override arranca vacío con el default del template
/// como placeholder. El `PUT` REEMPLAZA por completo, así que el form
/// representa el set deseado entero — vaciar un campo elimina su override. Las
/// keys editables son EXACTAMENTE las defs (un campo por variable); enviar una
/// key fuera del set daría 422 client-side evitable.
class BotVariablesPage extends StatelessWidget {
  const BotVariablesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<BotVariablesBloc, BotVariablesState>(
      listener: (context, state) {
        if (state is BotVariablesSaved) {
          // El messenger se resuelve antes del pop (ancestro del MaterialApp):
          // la confirmación sobrevive al desmontaje de la página.
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Variables guardadas')),
            );
          Navigator.of(context).maybePop();
        }
      },
      child: BlocBuilder<BotVariablesBloc, BotVariablesState>(
        builder: (context, state) => switch (state) {
          BotVariablesLoading() => const _LoadingView(),
          BotVariablesEmpty() => const _EmptyView(),
          BotVariablesFailed(error: final e) => _FailedView(error: e),
          BotVariablesLoaded(defs: final defs, currentValues: final values) =>
            _VariablesForm(defs: defs, currentValues: values, isSaving: false),
          BotVariablesSaving(defs: final defs, currentValues: final values) =>
            _VariablesForm(defs: defs, currentValues: values, isSaving: true),
          BotVariablesSaveFailed(
            defs: final defs,
            currentValues: final values,
            failure: final f,
          ) =>
            _VariablesForm(
              defs: defs,
              currentValues: values,
              isSaving: false,
              failure: f,
            ),
          // Transitorio: el listener ya hizo pop; un frame de spinner evita
          // reconstruir el form mientras se desmonta.
          BotVariablesSaved() => const _LoadingView(),
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Text(
          'Esta plantilla no declara variables.',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.error});

  final BotVariablesLoadError error;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              switch (error) {
                BotVariablesLoadError.notFound =>
                  'El bot o su plantilla ya no existen en tu organización.',
                BotVariablesLoadError.forbidden =>
                  'Tu rol no permite editar las variables de este bot.',
                BotVariablesLoadError.network =>
                  'Sin conexión. Revisa tu red e inténtalo de nuevo.',
                BotVariablesLoadError.generic =>
                  'No pudimos cargar las variables del bot.',
              },
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<BotVariablesBloc>().add(
                const BotVariablesLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form dinámico de N campos (uno por VariableDef). Stateful: posee los
/// controllers, keyeados por `def.id`. Cada uno se PRECARGA con el override
/// guardado (`currentValues[def.name]`) si existe; si no, arranca vacío y el
/// default del template va de placeholder (referencia).
///
/// Hasta 5 defs: todos los campos expandidos en un Column plano (caso
/// simple). Con más, modo compacto: buscador por nombre + una tarjeta
/// colapsable por variable. Colapsar o filtrar es PURAMENTE presentacional:
/// los controllers existen para TODOS los defs durante toda la vida del form
/// y el submit incluye cualquier valor no vacío, visible o no.
class _VariablesForm extends StatefulWidget {
  const _VariablesForm({
    required this.defs,
    required this.currentValues,
    required this.isSaving,
    this.failure,
  });

  final List<VariableDef> defs;
  final Map<String, String> currentValues;
  final bool isSaving;
  final BotsFailure? failure;

  @override
  State<_VariablesForm> createState() => _VariablesFormState();
}

class _VariablesFormState extends State<_VariablesForm> {
  /// Umbral del modo compacto: hasta este número de defs, Column plano con
  /// todos los campos a la vista; con más, buscador + tarjetas colapsables.
  static const int _flatMax = 5;

  late final Map<String, TextEditingController> _controllers;
  final TextEditingController _search = TextEditingController();

  /// Ids de defs con tarjeta expandida. SOLO presentación: los controllers
  /// existen para todos los defs y el submit los lee todos.
  final Set<String> _expanded = <String>{};

  bool get _isCompact => widget.defs.length > _flatMax;
  String get _query => _search.text.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    // Precarga por NOMBRE de variable (currentValues viene keyeado por name);
    // los controllers se keyean por id. Sin override ⇒ vacío (placeholder).
    _controllers = <String, TextEditingController>{
      for (final d in widget.defs)
        d.id: TextEditingController(text: widget.currentValues[d.name] ?? ''),
    };
    // Auto-expandir lo ya configurado: el operador quiere ver de entrada
    // qué overrides existen. El resto arranca colapsado.
    for (final d in widget.defs) {
      if ((widget.currentValues[d.name] ?? '').isNotEmpty) {
        _expanded.add(d.id);
      }
    }
    _search.addListener(_onSearchChanged);
  }

  /// Buscar AUTO-EXPANDE los matches además de filtrarlos: quien busca una
  /// variable la busca para editarla, sin tap extra. La expansión persiste
  /// al limpiar la búsqueda (el operador sigue editando donde lo dejó) y un
  /// tap en la tarjeta puede recolapsarla en cualquier momento.
  void _onSearchChanged() {
    final q = _query;
    if (q.isNotEmpty) {
      for (final d in widget.defs) {
        if (d.name.toLowerCase().contains(q)) {
          _expanded.add(d.id);
        }
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    // Keys ⊆ defs por construcción (iteramos las defs). Sólo los campos NO
    // vacíos viajan como override; vaciar todo => `{}` (replace a sin overrides,
    // jamás null).
    final values = <String, String>{};
    for (final d in widget.defs) {
      final text = _controllers[d.id]!.text.trim();
      if (text.isNotEmpty) {
        values[d.name] = text;
      }
    }
    context.read<BotVariablesBloc>().add(BotVariablesSaveRequested(values));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final failure = widget.failure;
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
            child: Text(
              'Estos valores reemplazan por completo los actuales. Los campos '
              'vienen con el valor ya configurado; lo que dejes en blanco usará '
              'el valor por defecto de la plantilla.',
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
          ),
          const SizedBox(height: AppTokens.sp5),
          if (!_isCompact)
            // Caso simple: todos los campos a la vista, con el nombre y la
            // descripción en el propio campo.
            for (final d in widget.defs) ...<Widget>[
              _valueField(d, label: d.name, helper: d.description),
              const SizedBox(height: AppTokens.sp4),
            ]
          else ...<Widget>[
            AppTextField(
              key: const Key('bot_variables.search'),
              label: 'Buscar',
              hint: 'Nombre de la variable',
              controller: _search,
            ),
            const SizedBox(height: AppTokens.sp4),
            ..._cards(textTheme),
          ],
          if (failure != null) ...<Widget>[
            Text(
              _failureMessage(failure),
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
            ),
            const SizedBox(height: AppTokens.sp3),
          ],
          AppButton.filled(
            key: const Key('bot_variables.submit'),
            label: 'Guardar variables',
            fullWidth: true,
            loading: widget.isSaving,
            onPressed: widget.isSaving ? null : _submit,
          ),
        ],
      ),
    );
  }

  /// Campo de override multilínea. El valor puede ser un párrafo completo
  /// (p.ej. un mensaje entero): piso de 3 líneas para invitar a escribir,
  /// techo de 8 para que un valor enorme scrollee dentro del campo en vez de
  /// comerse la pantalla. Sin textInputAction: Enter inserta salto de línea.
  Widget _valueField(VariableDef d, {required String label, String? helper}) =>
      AppTextField(
        key: Key('bot_variables.field.${d.name}'),
        label: label,
        hint: d.defaultValue,
        helperText: helper,
        controller: _controllers[d.id]!,
        enabled: !widget.isSaving,
        minLines: 3,
        maxLines: 8,
      );

  /// Tarjetas del modo compacto, ya filtradas por la búsqueda (contains
  /// case-insensitive sobre el nombre). Dentro de la tarjeta el campo se
  /// llama «Valor»: nombre y descripción ya viven en el header.
  List<Widget> _cards(TextTheme textTheme) {
    final q = _query;
    final visible = q.isEmpty
        ? widget.defs
        : widget.defs
              .where((d) => d.name.toLowerCase().contains(q))
              .toList(growable: false);
    if (visible.isEmpty) {
      return <Widget>[
        Text(
          'Sin resultados para "${_search.text.trim()}".',
          key: const Key('bot_variables.no_results'),
          style: textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: AppTokens.text2,
          ),
        ),
        const SizedBox(height: AppTokens.sp4),
      ];
    }
    return <Widget>[
      for (final d in visible) ...<Widget>[
        BotVariableCard(
          key: Key('bot_variables.card.${d.name}'),
          name: d.name,
          description: d.description,
          valueText: _controllers[d.id]!.text,
          expanded: _expanded.contains(d.id),
          onToggle: () => setState(() {
            if (!_expanded.remove(d.id)) {
              _expanded.add(d.id);
            }
          }),
          field: _valueField(d, label: 'Valor'),
        ),
        const SizedBox(height: AppTokens.cardGap),
      ],
    ];
  }

  static String _failureMessage(BotsFailure f) => switch (f) {
    BotsConflictFailure() =>
      'El bot cambió mientras editabas (versión desactualizada). Recarga y '
          'vuelve a guardar.',
    BotsInvalidCreateFailure() => 'Algún valor no es válido para su variable.',
    BotsForbiddenFailure() => 'Tu rol no permite editar las variables.',
    BotsNotFoundFailure() => 'Este bot ya no existe en tu organización.',
    BotsNetworkFailure() ||
    BotsTimeoutFailure() => 'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    BotsNotPausedFailure() ||
    BotsPairingNotStartedFailure() ||
    BotsPhoneRejectedFailure() ||
    BotsServerFailure() ||
    UnknownBotsFailure() =>
      'No pudimos guardar las variables. Inténtalo de nuevo.',
  };
}
