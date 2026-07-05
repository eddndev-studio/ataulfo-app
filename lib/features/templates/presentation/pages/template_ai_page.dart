import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../ai_catalog/presentation/bloc/catalog_bloc.dart';
import '../../../ai_catalog/presentation/widgets/ai_config_editor.dart';
import '../../../labels/presentation/bloc/labels_bloc.dart';
import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../bloc/template_detail_bloc.dart';
import '../widgets/silence_labels_sheet.dart';

/// Motor IA de una plantilla (`/templates/:id/ai`): información Y edición en
/// la misma superficie, sobre el [AiConfigEditor] compartido (stat tiles +
/// sheets por campo, gating por capacidades del catálogo). Cada edición es un
/// PUT con CAS sobre el `TemplateDetailBloc` (re-GET en 409); el name nunca
/// viaja modificado.
///
/// El prompt se LEE aquí (completo, seleccionable); se EDITA conversando
/// con el Entrenador — el CTA del pie lo lleva ahí.
class TemplateAiPage extends StatelessWidget {
  const TemplateAiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<TemplateDetailBloc, TemplateDetailState>(
      listener: (context, state) {
        if (state is TemplateDetailMutationFailed) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(content: Text(_failureCopy(state.failure))),
            );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Motor IA')),
        body: BlocBuilder<TemplateDetailBloc, TemplateDetailState>(
          builder: (context, state) => switch (state) {
            TemplateDetailLoading() => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
              ),
            ),
            TemplateDetailLoaded(template: final tpl) => _LoadedView(
              template: tpl,
              isMutating: false,
            ),
            TemplateDetailMutating(template: final tpl) => _LoadedView(
              template: tpl,
              isMutating: true,
            ),
            TemplateDetailMutationFailed(template: final tpl) => _LoadedView(
              template: tpl,
              isMutating: false,
            ),
            TemplateDetailFailed() => const _FailedView(),
          },
        ),
      ),
    );
  }

  static String _failureCopy(TemplatesFailure f) => switch (f) {
    TemplatesConflictFailure() =>
      'Tu edición estaba desactualizada; la refrescamos. Reintenta.',
    TemplatesInvalidUpdateFailure() => 'El valor no es válido para el motor.',
    TemplatesForbiddenFailure() => 'Tu rol no permite editar esta plantilla.',
    _ => 'No pudimos guardar el cambio. Inténtalo de nuevo.',
  };
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.template, required this.isMutating});

  /// La plantilla edita el AIConfig completo: todos los campos del editor.
  static const Set<AiConfigField> _fields = <AiConfigField>{
    AiConfigField.enabled,
    AiConfigField.model,
    AiConfigField.temperature,
    AiConfigField.thinking,
    AiConfigField.contextMessages,
    AiConfigField.responseDelay,
    AiConfigField.silenceLabels,
    AiConfigField.toolGroups,
    AiConfigField.subagent,
    AiConfigField.followUp,
  };

  final Template template;

  /// PUT en vuelo: los controles quedan inertes (sin doble dispatch).
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    final ai = template.ai;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp4,
        AppTokens.sp6,
        AppTokens.sp6 + context.safeBottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BlocBuilder<CatalogBloc, CatalogState>(
            builder: (context, catState) {
              final catalog = catState is CatalogLoaded
                  ? catState.catalog
                  : null;
              return AiConfigEditor(
                keyPrefix: 'template_ai',
                ai: ai,
                catalog: catalog,
                fields: _fields,
                editable: !isMutating,
                enabledLabel: 'IA habilitada',
                enabledCaption:
                    'Apagada, los bots de esta plantilla no responden con IA.',
                onChanged: (next) => context.read<TemplateDetailBloc>().add(
                  TemplateDetailAiUpdateRequested(next),
                ),
                pickSilenceLabels: _pickSilenceLabels,
              );
            },
          ),
          const SizedBox(height: AppTokens.sp6),
          Text(
            'Prompt del sistema',
            style: textTheme.titleMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp3),
          if (ai.systemPrompt.isEmpty)
            Text(
              'Sin prompt definido',
              style: textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppTokens.text2,
              ),
            )
          else
            // El prompt entero, seleccionable para copiar: esta página
            // existe para LEERLO; se edita conversando con el Entrenador.
            SelectableText(ai.systemPrompt, style: textTheme.bodyMedium),
          const SizedBox(height: AppTokens.sp7),
          AppButton.filled(
            key: const Key('template_ai.train_button'),
            label: 'Entrenar prompt',
            icon: Icons.school_outlined,
            fullWidth: true,
            // push apila el entrenador; back físico vuelve a esta ficha.
            onPressed: () => context.push('/templates/${template.id}/trainer'),
          ),
        ],
      ),
    );
  }

  /// Picker de etiquetas de silencio inyectado al editor: el catálogo
  /// (LabelsBloc) vive a nivel de ruta y el sheet abre en otra rama del
  /// árbol (navigator), así que se le pasa por value.
  static Future<List<String>?> _pickSilenceLabels(
    BuildContext context,
    List<String> current,
  ) {
    final labelsBloc = context.read<LabelsBloc>();
    return showAppBottomSheet<List<String>>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<LabelsBloc>.value(
        value: labelsBloc,
        child: SilenceLabelsSheet(initialSelectedIds: current),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No pudimos cargar el motor IA de la plantilla',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
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
