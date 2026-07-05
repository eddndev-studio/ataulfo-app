import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_create_bloc.dart';

/// Página para crear un Flow dentro de una Template (S11). Consume el
/// `FlowCreateBloc` del scope; el cableado del provider y del
/// templateId lo hace el router en `/templates/:templateId/flows/new`.
/// Es content-only: el Scaffold + AppBar los aporta la ruta.
class FlowCreatePage extends StatefulWidget {
  const FlowCreatePage({super.key});

  @override
  State<FlowCreatePage> createState() => _FlowCreatePageState();
}

class _FlowCreatePageState extends State<FlowCreatePage> {
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
    return BlocConsumer<FlowCreateBloc, FlowCreateState>(
      listener: (context, state) {
        if (state is FlowCreateSucceeded) {
          // pushReplacement: reemplaza /flows/new con el detalle del
          // flujo recién creado. Back físico vuelve al TemplateDetailPage
          // (el frame del form ya cumplió su función). go() aplastaría
          // la pila completa.
          context.pushReplacement('/flows/${state.flow.id}');
        }
      },
      builder: (context, state) {
        final submitting = state is FlowCreateSubmitting;
        return Padding(
          padding: const EdgeInsets.all(AppTokens.sp6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
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
