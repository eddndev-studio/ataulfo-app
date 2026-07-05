import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../../domain/repositories/templates_repository.dart';
import '../bloc/template_create_bloc.dart';

/// Hoja de creación de una Template. Reemplaza a la pantalla dedicada: el mismo
/// formulario (nombre + crear) vive ahora en un bottom sheet. Al crear con
/// éxito CIERRA devolviendo la Template creada vía `Navigator.pop`; quien la
/// abre decide la navegación (típicamente empujar el detalle), lo que evita el
/// footgun de navegar desde un contexto que muere al cerrar la hoja.
///
/// Un modal vive en otro subárbol del Navigator —fuera de los providers del
/// shell—, así que el repositorio se LEE en el call site y se inyecta al bloc
/// de la hoja con `create:`.
class TemplateCreateSheet extends StatefulWidget {
  const TemplateCreateSheet({super.key});

  /// Abre la hoja y resuelve con la Template creada, o `null` si se descartó
  /// sin crear. El llamador (FAB, empty-state) navega con el resultado.
  static Future<Template?> open(BuildContext context) {
    final repo = context.read<TemplatesRepository>();
    return showAppBottomSheet<Template>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<TemplateCreateBloc>(
        create: (_) => TemplateCreateBloc(repo: repo),
        child: const TemplateCreateSheet(),
      ),
    );
  }

  @override
  State<TemplateCreateSheet> createState() => _TemplateCreateSheetState();
}

class _TemplateCreateSheetState extends State<TemplateCreateSheet> {
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
    final textTheme = Theme.of(context).textTheme;
    return BlocConsumer<TemplateCreateBloc, TemplateCreateState>(
      listener: (context, state) {
        if (state is TemplateCreateSucceeded) {
          Navigator.of(context).pop(state.template);
        }
      },
      builder: (context, state) {
        final submitting = state is TemplateCreateSubmitting;
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
              Text('Nueva plantilla', style: textTheme.titleLarge),
              const SizedBox(height: AppTokens.sp4),
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
                fullWidth: true,
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
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
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
