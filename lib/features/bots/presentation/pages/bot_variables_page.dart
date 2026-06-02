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

/// Editor de `variable_values` de un Bot (S04), sub-página ruteada
/// (`/bots/:id/variables`). Content-only: el Scaffold/AppBar los aporta la ruta.
///
/// WRITE-ONLY de primer orden: `botResp` no devuelve los overrides guardados,
/// así que el form NUNCA los prellena — siembra placeholders desde los defaults
/// del template y el `PUT` REEMPLAZA por completo. El banner lo deja explícito.
/// Las keys editables son EXACTAMENTE las defs (un campo por variable); enviar
/// una key fuera del set daría 422 client-side evitable.
class BotVariablesPage extends StatelessWidget {
  const BotVariablesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<BotVariablesBloc, BotVariablesState>(
      listener: (context, state) {
        if (state is BotVariablesSaved) {
          Navigator.of(context).maybePop();
        }
      },
      child: BlocBuilder<BotVariablesBloc, BotVariablesState>(
        builder: (context, state) => switch (state) {
          BotVariablesLoading() => const _LoadingView(),
          BotVariablesEmpty() => const _EmptyView(),
          BotVariablesFailed(error: final e) => _FailedView(error: e),
          BotVariablesLoaded(defs: final defs) => _VariablesForm(
            defs: defs,
            isSaving: false,
          ),
          BotVariablesSaving(defs: final defs) => _VariablesForm(
            defs: defs,
            isSaving: true,
          ),
          BotVariablesSaveFailed(defs: final defs, failure: final f) =>
            _VariablesForm(defs: defs, isSaving: false, failure: f),
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
/// controllers, keyeados por `def.id`, todos vacíos al abrir (WRITE-ONLY: no
/// hay overrides que prellenar). El default va de placeholder (referencia).
class _VariablesForm extends StatefulWidget {
  const _VariablesForm({
    required this.defs,
    required this.isSaving,
    this.failure,
  });

  final List<VariableDef> defs;
  final bool isSaving;
  final BotsFailure? failure;

  @override
  State<_VariablesForm> createState() => _VariablesFormState();
}

class _VariablesFormState extends State<_VariablesForm> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = <String, TextEditingController>{
      for (final d in widget.defs) d.id: TextEditingController(),
    };
  }

  @override
  void dispose() {
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
              'Estos valores reemplazan por completo los actuales. Los valores '
              'guardados no se muestran (limitación del servidor): lo que dejes '
              'en blanco usará el valor por defecto de la plantilla.',
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
          ),
          const SizedBox(height: AppTokens.sp5),
          for (final d in widget.defs) ...<Widget>[
            AppTextField(
              key: Key('bot_variables.field.${d.name}'),
              label: d.name,
              hint: d.defaultValue,
              helperText: d.description,
              controller: _controllers[d.id]!,
              enabled: !widget.isSaving,
            ),
            const SizedBox(height: AppTokens.sp4),
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

  static String _failureMessage(BotsFailure f) => switch (f) {
    BotsConflictFailure() =>
      'El bot cambió mientras editabas (versión desactualizada). Recarga y '
          'vuelve a guardar.',
    BotsInvalidCreateFailure() => 'Algún valor no es válido para su variable.',
    BotsForbiddenFailure() => 'Tu rol no permite editar las variables.',
    BotsNotFoundFailure() => 'Este bot ya no existe en tu organización.',
    BotsNetworkFailure() ||
    BotsTimeoutFailure() => 'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    BotsServerFailure() || UnknownBotsFailure() =>
      'No pudimos guardar las variables. Inténtalo de nuevo.',
  };
}
