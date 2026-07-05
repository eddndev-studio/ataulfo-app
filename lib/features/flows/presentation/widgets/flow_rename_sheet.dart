import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/flow.dart' as fdom;
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_detail_bloc.dart';

/// Hoja de renombrado de un Flow. SOLO el nombre — la configuración vive
/// en su propia página: renombrar es una micro-tarea y no amerita
/// pantalla. Despacha sobre el `FlowDetailBloc` del scope y refleja el
/// resultado: loading mientras el PUT está en vuelo, copy de error si
/// falla, cierre automático al éxito.
///
/// Un modal vive en otro subárbol del Navigator, así que `open`
/// re-provee el bloc del scope con `BlocProvider.value` (patrón
/// TemplateRenameSheet).
class FlowRenameSheet extends StatefulWidget {
  const FlowRenameSheet({super.key, required this.flow});

  final fdom.Flow flow;

  static void open(BuildContext context, fdom.Flow flow) {
    final bloc = context.read<FlowDetailBloc>();
    showAppBottomSheet<void>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<FlowDetailBloc>.value(
        value: bloc,
        child: FlowRenameSheet(flow: flow),
      ),
    );
  }

  @override
  State<FlowRenameSheet> createState() => _FlowRenameSheetState();
}

class _FlowRenameSheetState extends State<FlowRenameSheet> {
  static const int _nameMaxLen = 80;

  late final TextEditingController _nameCtrl;

  /// `true` solo tras despachar el rename: el cierre automático en
  /// Loaded aplica únicamente a una mutación propia, no a rebuilds
  /// incidentales del bloc compartido.
  bool _didSubmit = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.flow.name);
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
    context.read<FlowDetailBloc>().add(
      FlowDetailRenameRequested(_nameCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocListener<FlowDetailBloc, FlowDetailState>(
      listener: (context, state) {
        // Tras una mutación propia exitosa el bloc vuelve a Loaded: cierra.
        if (_didSubmit && state is FlowDetailLoaded) {
          Navigator.of(context).maybePop();
        }
      },
      child: BlocBuilder<FlowDetailBloc, FlowDetailState>(
        builder: (context, state) {
          final isMutating = state is FlowDetailMutating;
          final failure = state is FlowDetailMutationFailed
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
                Text('Renombrar flujo', style: textTheme.titleLarge),
                const SizedBox(height: AppTokens.sp4),
                AppTextField(
                  key: const Key('flow_rename.name'),
                  label: 'Nombre',
                  hint: 'Nombre del flujo',
                  controller: _nameCtrl,
                  enabled: !isMutating,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(_nameMaxLen),
                  ],
                ),
                if (_didSubmit && failure != null) ...<Widget>[
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
                  key: const Key('flow_rename.submit'),
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

  static String _failureMessage(FlowsFailure f) => switch (f) {
    FlowsConflictFailure() =>
      'Otro operador editó este flujo. Cierra la hoja, revisa y reintenta.',
    FlowsInvalidSettingsFailure() || FlowsInvalidCreateFailure() =>
      'El nombre no es válido. Revísalo e inténtalo de nuevo.',
    FlowsForbiddenFailure() => 'Tu rol no permite editar este flujo.',
    FlowsNotFoundFailure() => 'Este flujo ya no existe en tu organización.',
    FlowsNetworkFailure() || FlowsTimeoutFailure() =>
      'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    _ => 'No pudimos guardar el cambio. Inténtalo de nuevo.',
  };
}
