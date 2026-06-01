import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/wa_label.dart';
import '../../domain/failures/wa_labels_failure.dart';
import '../bloc/wa_labels_bloc.dart';
import 'wa_label_palette.dart';
import 'wa_label_swatch.dart';

/// Sheet de creación/edición de una etiqueta WhatsApp (S21). Crea si `editing`
/// es null, edita en caso contrario. El nombre y el índice de paleta se empujan
/// a WhatsApp por el backend; el sheet refleja el resultado de la mutación
/// (spinner mientras está en vuelo, copy de error si falla, cierre al éxito).
///
/// Despacha sobre el `WaLabelsBloc` del scope. Los helpers estáticos abren el
/// sheet pasándole ese bloc (un modal vive en otro subárbol del Navigator).
class WaLabelEditSheet extends StatefulWidget {
  const WaLabelEditSheet({super.key, required this.editing});

  final WaLabel? editing;

  static void openCreate(BuildContext context) => _open(context, null);

  static void openEdit(BuildContext context, WaLabel label) =>
      _open(context, label);

  static void _open(BuildContext context, WaLabel? editing) {
    final bloc = context.read<WaLabelsBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<WaLabelsBloc>.value(
        value: bloc,
        child: WaLabelEditSheet(editing: editing),
      ),
    );
  }

  @override
  State<WaLabelEditSheet> createState() => _WaLabelEditSheetState();
}

class _WaLabelEditSheetState extends State<WaLabelEditSheet> {
  late final TextEditingController _nameCtrl;
  late int _color;
  bool _didSubmit = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.editing?.name ?? '');
    _color = widget.editing?.color ?? 0;
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
    final name = _nameCtrl.text.trim();
    final ed = widget.editing;
    _didSubmit = true;
    final bloc = context.read<WaLabelsBloc>();
    if (ed == null) {
      bloc.add(WaLabelsAddRequested(name: name, color: _color));
    } else {
      bloc.add(
        WaLabelsUpdateRequested(
          waLabelId: ed.waLabelId,
          name: name,
          color: _color,
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final ed = widget.editing;
    if (ed == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar etiqueta?'),
        content: const Text(
          'Se quitará de WhatsApp y de todos los chats que la tengan. Esta '
          'acción no se puede deshacer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('wa_edit.delete_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppTokens.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _didSubmit = true;
    context.read<WaLabelsBloc>().add(
      WaLabelsDeleteRequested(waLabelId: ed.waLabelId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isEditing = widget.editing != null;
    return BlocListener<WaLabelsBloc, WaLabelsState>(
      listener: (context, state) {
        // Tras una mutación propia exitosa el bloc vuelve a Loaded: cierra.
        if (_didSubmit && state is WaLabelsLoaded) {
          Navigator.of(context).maybePop();
        }
      },
      child: BlocBuilder<WaLabelsBloc, WaLabelsState>(
        builder: (context, state) {
          final isMutating = state is WaLabelsMutating;
          final failure = state is WaLabelsMutationFailed
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
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        isEditing ? 'Editar etiqueta' : 'Nueva etiqueta',
                        style: textTheme.titleLarge,
                      ),
                    ),
                    if (isEditing)
                      IconButton(
                        key: const Key('wa_edit.delete'),
                        tooltip: 'Eliminar etiqueta',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTokens.danger,
                        ),
                        onPressed: isMutating ? null : _confirmDelete,
                      ),
                  ],
                ),
                const SizedBox(height: AppTokens.sp4),
                AppTextField(
                  key: const Key('wa_edit.name'),
                  label: 'Nombre',
                  hint: 'Cliente VIP',
                  controller: _nameCtrl,
                  enabled: !isMutating,
                  autofocus: !isEditing,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppTokens.sp4),
                Text(
                  'Color',
                  style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
                ),
                const SizedBox(height: AppTokens.sp2),
                _PalettePicker(
                  selected: _color,
                  enabled: !isMutating,
                  onSelected: (i) => setState(() => _color = i),
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
                  key: const Key('wa_edit.submit'),
                  label: isEditing ? 'Guardar' : 'Crear',
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

  static String _failureMessage(WaLabelsFailure f) => switch (f) {
    WaLabelsNotConnectedFailure() =>
      'El bot no está conectado a WhatsApp. Conéctalo e inténtalo de nuevo.',
    WaLabelsUpstreamFailure() =>
      'WhatsApp no respondió. Inténtalo de nuevo en un momento.',
    WaLabelsInvalidFailure() => 'Revisa el nombre de la etiqueta.',
    WaLabelsForbiddenFailure() =>
      'No tienes permiso para gestionar etiquetas en este bot.',
    WaLabelsNotFoundFailure() => 'Este bot ya no existe en tu organización.',
    WaLabelsNetworkFailure() || WaLabelsTimeoutFailure() =>
      'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    WaLabelsServerFailure() ||
    WaLabelsUnknownFailure() => 'Algo salió mal. Inténtalo de nuevo.',
  };
}

/// Rejilla de swatches para elegir el índice de paleta de WhatsApp. El
/// seleccionado lleva un anillo de marca. Tocar un swatch fija el índice.
class _PalettePicker extends StatelessWidget {
  const _PalettePicker({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final int selected;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.sp3,
      runSpacing: AppTokens.sp3,
      children: <Widget>[
        for (var i = 0; i < WaLabelPalette.colors.length; i++)
          GestureDetector(
            key: Key('wa_palette.$i'),
            onTap: enabled ? () => onSelected(i) : null,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: i == selected ? AppTokens.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: WaLabelSwatch(colorIndex: i, size: 28),
            ),
          ),
      ],
    );
  }
}
