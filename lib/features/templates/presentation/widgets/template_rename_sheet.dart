import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../bloc/template_detail_bloc.dart';

/// Hoja de renombrado de una Template. SOLO el nombre — el motor IA se
/// edita en su propia página (separación de responsabilidades): renombrar
/// es una micro-tarea y no amerita pantalla dedicada. Despacha sobre el
/// `TemplateDetailBloc` del scope y refleja el resultado: loading mientras
/// el PUT está en vuelo, copy de error si falla, cierre automático al éxito.
///
/// Un modal vive en otro subárbol del Navigator, así que `open` re-provee
/// el bloc del scope con `BlocProvider.value` (patrón BotEditSheet).
class TemplateRenameSheet extends StatefulWidget {
  const TemplateRenameSheet({super.key, required this.template});

  final Template template;

  static void open(BuildContext context, Template template) {
    final bloc = context.read<TemplateDetailBloc>();
    showAppBottomSheet<void>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<TemplateDetailBloc>.value(
        value: bloc,
        child: TemplateRenameSheet(template: template),
      ),
    );
  }

  @override
  State<TemplateRenameSheet> createState() => _TemplateRenameSheetState();
}

class _TemplateRenameSheetState extends State<TemplateRenameSheet> {
  static const int _nameMaxLen = 80;

  late final TextEditingController _nameCtrl;
  bool _didSubmit = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template.name);
    _nameCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  bool get _isSubmittable => _nameCtrl.text.trim().isNotEmpty;

  void _submit() {
    if (!_isSubmittable) return;
    _didSubmit = true;
    context.read<TemplateDetailBloc>().add(
      TemplateDetailRenameRequested(_nameCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocListener<TemplateDetailBloc, TemplateDetailState>(
      listener: (context, state) {
        // Tras una mutación propia exitosa el bloc vuelve a Loaded: cierra.
        if (_didSubmit && state is TemplateDetailLoaded) {
          Navigator.of(context).maybePop();
        }
      },
      child: BlocBuilder<TemplateDetailBloc, TemplateDetailState>(
        builder: (context, state) {
          final isMutating = state is TemplateDetailMutating;
          final failure = state is TemplateDetailMutationFailed
              ? state.failure
              : null;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppTokens.sp6,
              AppTokens.sp6,
              AppTokens.sp6,
              AppTokens.sp6 + context.sheetBottomInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Renombrar Asistente', style: textTheme.titleLarge),
                const SizedBox(height: AppTokens.sp4),
                AppTextField(
                  key: const Key('template_rename.name'),
                  label: 'Nombre',
                  hint: 'Nombre del Asistente',
                  controller: _nameCtrl,
                  enabled: !isMutating,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(_nameMaxLen),
                  ],
                ),
                if (failure != null) ...<Widget>[
                  const SizedBox(height: AppTokens.sp3),
                  Text(
                    _failureMessage(failure),
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTokens.danger,
                    ),
                  ),
                ],
                const SizedBox(height: AppTokens.sp5),
                AppButton.filled(
                  key: const Key('template_rename.submit'),
                  label: 'Guardar',
                  fullWidth: true,
                  loading: isMutating,
                  onPressed: _isSubmittable ? _submit : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _failureMessage(TemplatesFailure f) => switch (f) {
    TemplatesConflictFailure() =>
      'Tu edición estaba desactualizada; la refrescamos. Revisa y reintenta.',
    TemplatesInvalidUpdateFailure() =>
      'El nombre no es válido. Revísalo e inténtalo de nuevo.',
    TemplatesForbiddenFailure() => 'Tu rol no permite editar este Asistente.',
    TemplatesNotFoundFailure() =>
      'Este Asistente ya no existe en tu organización.',
    TemplatesNetworkFailure() || TemplatesTimeoutFailure() =>
      'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    _ => 'No pudimos guardar el cambio. Inténtalo de nuevo.',
  };
}
