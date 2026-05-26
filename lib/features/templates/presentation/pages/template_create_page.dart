import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/failures/templates_failure.dart';
import '../bloc/template_create_bloc.dart';

/// Página para crear una Template. Consume el `TemplateCreateBloc` del scope;
/// el cableado del provider lo hace el router en `/templates/new`. Es
/// content-only: el Scaffold y el AppBar los aporta la ruta.
class TemplateCreatePage extends StatefulWidget {
  const TemplateCreatePage({super.key});

  @override
  State<TemplateCreatePage> createState() => _TemplateCreatePageState();
}

class _TemplateCreatePageState extends State<TemplateCreatePage> {
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
    context.read<TemplateCreateBloc>().add(TemplateCreateSubmitted(name: name));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TemplateCreateBloc, TemplateCreateState>(
      listener: (context, state) {
        if (state is TemplateCreateSucceeded) {
          // pushReplacement: reemplaza /templates/new con el detalle
          // (back del detalle NO vuelve al formulario que ya cumplió su
          // función) pero preserva el shell debajo, así el back físico
          // de Android vuelve al listado. context.go() aplastaría la
          // pila y sacaría al usuario de la app.
          context.pushReplacement('/templates/${state.template.id}');
        }
      },
      builder: (context, state) {
        final submitting = state is TemplateCreateSubmitting;
        return Padding(
          padding: const EdgeInsets.all(AppTokens.sp6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                key: const Key('template_create.field.name'),
                label: 'Nombre de la plantilla',
                hint: 'Ej. Soporte ventas',
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
                key: const Key('template_create.submit'),
                label: 'Crear',
                // El primitivo bloquea el tap cuando loading=true sin
                // nullificar onPressed: pasamos el callback inalterado
                // y dejamos el gate de submitting al primitivo.
                onPressed: _canSubmit ? _submit : null,
                loading: submitting,
              ),
              if (state is TemplateCreateFailed) ...<Widget>[
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
    TemplatesInvalidNameFailure() => (
      'template_create.error.invalid_name',
      'Revisa el nombre: no puede estar vacío ni exceder el límite.',
    ),
    TemplatesForbiddenFailure() => (
      'template_create.error.forbidden',
      'Tu rol no permite crear plantillas. Pide acceso a un admin.',
    ),
    TemplatesNetworkFailure() || TemplatesTimeoutFailure() => (
      'template_create.error.network',
      'Sin conexión con el servidor. Revisa tu red y reintenta.',
    ),
    TemplatesNotFoundFailure() ||
    TemplatesInvalidUpdateFailure() ||
    TemplatesConflictFailure() ||
    TemplatesServerFailure() ||
    UnknownTemplatesFailure() => (
      'template_create.error.generic',
      'No pudimos crear la plantilla. Inténtalo de nuevo.',
    ),
  };
}
