import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../bloc/template_edit_bloc.dart';

/// Página para editar nombre + system prompt de una Template (TE1).
///
/// Content-only: el Scaffold y el AppBar los aporta la ruta. El bloc se
/// monta page-scoped en `/templates/:id/edit` y arranca cargando el
/// template (Loading sin flash de Initial); la página se re-construye
/// con un form pre-filled cuando el bloc entra en Editing.
///
/// Al persistir cambios (Succeeded), `pushReplacement` reemplaza la
/// ruta del editor con el detalle: el back físico vuelve al listado sin
/// pasar por el form que ya cumplió. El AIConfig se preserva entero
/// (TE1 no edita provider/model/temp/etc.); el bloc lo serializa con
/// los campos no-editables del template cargado.
class TemplateEditPage extends StatelessWidget {
  const TemplateEditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TemplateEditBloc, TemplateEditState>(
      listenWhen: (prev, next) => next is TemplateEditSucceeded,
      listener: (context, state) {
        if (state is TemplateEditSucceeded) {
          context.pushReplacement('/templates/${state.template.id}');
        }
      },
      builder: (context, state) => switch (state) {
        TemplateEditLoading() => const _LoadingView(),
        TemplateEditLoadFailed(failure: final f) => _LoadFailedView(failure: f),
        TemplateEditEditing(template: final t) => _EditForm(
          template: t,
          submitting: false,
          submitFailure: null,
        ),
        TemplateEditSubmitting(template: final t) => _EditForm(
          template: t,
          submitting: true,
          submitFailure: null,
        ),
        TemplateEditSubmitFailed(failure: final f, template: final t) =>
          _EditForm(template: t, submitting: false, submitFailure: f),
        TemplateEditSucceeded(template: final t) => _EditForm(
          template: t,
          submitting: true, // mantiene el botón en loading hasta la navegación
          submitFailure: null,
        ),
      },
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

class _LoadFailedView extends StatelessWidget {
  const _LoadFailedView({required this.failure});

  final TemplatesFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final copy = failure is TemplatesNotFoundFailure
        ? 'Esta plantilla ya no existe en tu organización.'
        : 'No pudimos cargar la plantilla. Inténtalo de nuevo.';
    return Center(
      key: const Key('template_edit.load_error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(copy, textAlign: TextAlign.center, style: textTheme.bodyLarge),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<TemplateEditBloc>().add(
                const TemplateEditLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditForm extends StatefulWidget {
  const _EditForm({
    required this.template,
    required this.submitting,
    required this.submitFailure,
  });

  final Template template;
  final bool submitting;
  final TemplatesFailure? submitFailure;

  @override
  State<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends State<_EditForm> {
  late final TextEditingController _name;
  late final TextEditingController _systemPrompt;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.template.name);
    _systemPrompt = TextEditingController(
      text: widget.template.ai.systemPrompt,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _systemPrompt.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    context.read<TemplateEditBloc>().add(
      TemplateEditSubmitted(name: name, systemPrompt: _systemPrompt.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.sp6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            key: const Key('template_edit.field.name'),
            label: 'Nombre de la plantilla',
            hint: 'Ej. Soporte ventas',
            controller: _name,
            enabled: !widget.submitting,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppTokens.sp4),
          AppTextField(
            key: const Key('template_edit.field.system_prompt'),
            label: 'Instrucción del sistema',
            hint: 'Define el rol y el tono del asistente…',
            controller: _systemPrompt,
            enabled: !widget.submitting,
            minLines: 4,
            maxLines: 12,
          ),
          const SizedBox(height: AppTokens.sp4),
          AppButton.filled(
            key: const Key('template_edit.submit'),
            label: 'Guardar',
            onPressed: _submit,
            loading: widget.submitting,
          ),
          if (widget.submitFailure != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            _SubmitFailedView(failure: widget.submitFailure!),
          ],
        ],
      ),
    );
  }
}

class _SubmitFailedView extends StatelessWidget {
  const _SubmitFailedView({required this.failure});

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
    TemplatesConflictFailure() => (
      'template_edit.error.conflict',
      'Esta plantilla fue editada en otro lugar. Recarga para ver la '
          'versión actual antes de guardar.',
    ),
    TemplatesInvalidUpdateFailure() => (
      'template_edit.error.invalid',
      'Revisa los datos: alguno no cumple las reglas de validación.',
    ),
    TemplatesForbiddenFailure() => (
      'template_edit.error.forbidden',
      'Tu rol no permite editar plantillas. Pide acceso a un admin.',
    ),
    TemplatesNetworkFailure() || TemplatesTimeoutFailure() => (
      'template_edit.error.network',
      'Sin conexión con el servidor. Revisa tu red y reintenta.',
    ),
    TemplatesNotFoundFailure() ||
    TemplatesInvalidNameFailure() ||
    TemplatesServerFailure() ||
    UnknownTemplatesFailure() => (
      'template_edit.error.generic',
      'No pudimos guardar los cambios. Inténtalo de nuevo.',
    ),
  };
}
