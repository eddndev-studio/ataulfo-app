import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/flow.dart' as fdom;
import '../../domain/failures/flows_failure.dart';
import '../../domain/repositories/flows_repository.dart';
import '../bloc/flow_create_bloc.dart';

/// Hoja de creación de un Flow dentro de una Template. Reemplaza a la
/// pantalla dedicada: el mismo formulario (nombre + crear) vive ahora en un
/// bottom sheet. Al crear con éxito CIERRA devolviendo el Flow creado vía
/// `Navigator.pop`; quien la abre decide la navegación (típicamente empujar
/// el editor), lo que evita el footgun de navegar desde un contexto que
/// muere al cerrar la hoja.
///
/// Un modal vive en otro subárbol del Navigator —fuera de los providers de
/// la ruta—, así que el repositorio se LEE en el call site y se inyecta al
/// bloc de la hoja con `create:`.
class FlowCreateSheet extends StatefulWidget {
  const FlowCreateSheet({super.key});

  /// Abre la hoja y resuelve con el Flow creado, o `null` si se descartó
  /// sin crear. El llamador (FAB) navega con el resultado.
  static Future<fdom.Flow?> open(
    BuildContext context, {
    required String templateId,
  }) {
    final repo = context.read<FlowsRepository>();
    return showAppBottomSheet<fdom.Flow>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<FlowCreateBloc>(
        create: (_) => FlowCreateBloc(repo: repo, templateId: templateId),
        child: const FlowCreateSheet(),
      ),
    );
  }

  @override
  State<FlowCreateSheet> createState() => _FlowCreateSheetState();
}

class _FlowCreateSheetState extends State<FlowCreateSheet> {
  final TextEditingController _ctrl = TextEditingController();
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_recomputeCanSubmit);
  }

  void _recomputeCanSubmit() {
    final next = _ctrl.text.trim().isNotEmpty;
    if (next != _canSubmit) {
      setState(() => _canSubmit = next);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_recomputeCanSubmit);
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    context.read<FlowCreateBloc>().add(FlowCreateSubmitted(name: name));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocConsumer<FlowCreateBloc, FlowCreateState>(
      listener: (context, state) {
        if (state is FlowCreateSucceeded) {
          Navigator.of(context).pop(state.flow);
        }
      },
      builder: (context, state) {
        final submitting = state is FlowCreateSubmitting;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppTokens.sp6,
            AppTokens.sp6,
            AppTokens.sp6,
            AppTokens.sp6 + context.sheetBottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Nuevo flujo', style: textTheme.titleLarge),
              const SizedBox(height: AppTokens.sp4),
              AppTextField(
                key: const Key('flow_create.field.name'),
                label: 'Nombre del flujo',
                hint: 'Ej. Bienvenida',
                controller: _ctrl,
                enabled: !submitting,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (_canSubmit) _submit();
                },
              ),
              const SizedBox(height: AppTokens.sp4),
              AppButton.filled(
                key: const Key('flow_create.submit'),
                label: 'Crear',
                fullWidth: true,
                onPressed: _canSubmit ? _submit : null,
                loading: submitting,
              ),
              if (state is FlowCreateFailed) ...<Widget>[
                const SizedBox(height: AppTokens.sp4),
                _FailedView(failure: state.failure),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final FlowsFailure failure;

  @override
  Widget build(BuildContext context) {
    final (key, copy) = _resolve(failure);
    return Text(
      copy,
      key: Key(key),
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
    );
  }

  static (String key, String copy) _resolve(FlowsFailure f) => switch (f) {
    FlowsInvalidCreateFailure() => (
      'flow_create.error.invalid_create',
      'Revisa el nombre: no puede estar vacío ni exceder el límite.',
    ),
    FlowsForbiddenFailure() => (
      'flow_create.error.forbidden',
      'Tu rol no permite crear flujos. Pide acceso a un admin.',
    ),
    FlowsNetworkFailure() || FlowsTimeoutFailure() => (
      'flow_create.error.network',
      'Sin conexión con el servidor. Revisa tu red y reintenta.',
    ),
    FlowsNotFoundFailure() ||
    FlowsServerFailure() ||
    FlowsInvalidStepFailure() ||
    FlowsStepNotFoundFailure() ||
    FlowsInvalidSettingsFailure() ||
    FlowsConflictFailure() ||
    FlowsInvalidReorderFailure() ||
    FlowsStepReferencedFailure() ||
    UnknownFlowsFailure() => (
      'flow_create.error.generic',
      'No pudimos crear el flujo. Inténtalo de nuevo.',
    ),
  };
}
