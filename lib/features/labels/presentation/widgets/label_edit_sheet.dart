import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/label.dart';
import '../../domain/failures/labels_failure.dart';
import '../bloc/labels_admin_bloc.dart';
import 'label_color_palette.dart';
import 'label_dot.dart';

/// Hoja de creación/edición de un Label interno (S10). Crea si `editing` es
/// null, edita en caso contrario. Despacha sobre el `LabelsAdminBloc` del scope
/// y refleja el resultado de la mutación: spinner mientras está en vuelo, copy
/// de error si falla, cierre automático al éxito.
///
/// Un modal vive en otro subárbol del Navigator, así que los helpers estáticos
/// re-proveen el bloc del scope a la hoja con `BlocProvider.value`.
class LabelEditSheet extends StatefulWidget {
  const LabelEditSheet({super.key, required this.editing});

  final Label? editing;

  static void openCreate(BuildContext context) => _open(context, null);

  static void openEdit(BuildContext context, Label label) =>
      _open(context, label);

  static void _open(BuildContext context, Label? editing) {
    final bloc = context.read<LabelsAdminBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<LabelsAdminBloc>.value(
        value: bloc,
        child: LabelEditSheet(editing: editing),
      ),
    );
  }

  @override
  State<LabelEditSheet> createState() => _LabelEditSheetState();
}

class _LabelEditSheetState extends State<LabelEditSheet> {
  static const int _nameMaxLen = 50;
  static const int _descMaxLen = 280;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late String _color;
  bool _didSubmit = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.editing?.name ?? '');
    _descCtrl = TextEditingController(text: widget.editing?.description ?? '');
    final editingColor = widget.editing?.color;
    _color = (editingColor != null && editingColor.trim().isNotEmpty)
        ? editingColor
        : LabelColorPalette.hexColors.first;
    _nameCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_onChanged)
      ..dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _isSubmittable => _nameCtrl.text.trim().isNotEmpty;

  void _submit() {
    if (!_isSubmittable) return;
    final name = _nameCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final ed = widget.editing;
    _didSubmit = true;
    final bloc = context.read<LabelsAdminBloc>();
    if (ed == null) {
      bloc.add(
        LabelsAdminCreateRequested(
          name: name,
          color: _color,
          description: description,
        ),
      );
    } else {
      bloc.add(
        LabelsAdminUpdateRequested(
          id: ed.id,
          name: name,
          color: _color,
          description: description,
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
          'Se quitará de todas las conversaciones que la tengan y de los '
          'disparadores que la usen. Esta acción no se puede deshacer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('label_edit.delete_confirm'),
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
    context.read<LabelsAdminBloc>().add(LabelsAdminDeleteRequested(id: ed.id));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isEditing = widget.editing != null;
    return BlocListener<LabelsAdminBloc, LabelsAdminState>(
      listener: (context, state) {
        // Tras una mutación propia exitosa el bloc vuelve a Loaded: cierra.
        if (_didSubmit && state is LabelsAdminLoaded) {
          Navigator.of(context).maybePop();
        }
      },
      child: BlocBuilder<LabelsAdminBloc, LabelsAdminState>(
        builder: (context, state) {
          final isMutating = state is LabelsAdminMutating;
          final failure = state is LabelsAdminMutationFailed
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
                        key: const Key('label_edit.delete'),
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
                  key: const Key('label_edit.name'),
                  label: 'Nombre',
                  hint: 'Cliente VIP',
                  controller: _nameCtrl,
                  enabled: !isMutating,
                  autofocus: !isEditing,
                  textInputAction: TextInputAction.next,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(_nameMaxLen),
                  ],
                ),
                const SizedBox(height: AppTokens.sp4),
                Text(
                  'Color',
                  style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
                ),
                const SizedBox(height: AppTokens.sp2),
                _ColorPicker(
                  selected: _color,
                  enabled: !isMutating,
                  onSelected: (hex) => setState(() => _color = hex),
                ),
                const SizedBox(height: AppTokens.sp4),
                AppTextField(
                  key: const Key('label_edit.description'),
                  label: 'Descripción (opcional)',
                  hint: 'Para qué sirve esta etiqueta',
                  controller: _descCtrl,
                  enabled: !isMutating,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(_descMaxLen),
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
                  key: const Key('label_edit.submit'),
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

  static String _failureMessage(LabelsFailure f) => switch (f) {
    LabelsDuplicateNameFailure() =>
      'Ya existe una etiqueta con ese nombre. Elige otro.',
    LabelsValidationFailure() => 'Revisa el nombre y el color de la etiqueta.',
    LabelsForbiddenFailure() => 'No tienes permiso para gestionar etiquetas.',
    LabelsNotFoundFailure() => 'Esta etiqueta ya no existe.',
    LabelsNetworkFailure() || LabelsTimeoutFailure() =>
      'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    LabelsServerFailure() ||
    LabelsUnknownFailure() => 'Algo salió mal. Inténtalo de nuevo.',
  };
}

/// Rejilla de swatches hex. El seleccionado lleva un anillo de marca. Si el
/// color vigente no está en la paleta curada (p. ej. creado por API), se
/// muestra como swatch extra al inicio para no perderlo.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final String selected;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final lower = selected.trim().toLowerCase();
    final inPalette = LabelColorPalette.hexColors.any(
      (c) => c.toLowerCase() == lower,
    );
    return Wrap(
      spacing: AppTokens.sp3,
      runSpacing: AppTokens.sp3,
      children: <Widget>[
        if (!inPalette)
          _Swatch(
            swatchKey: const Key('label_palette.current'),
            hex: selected,
            selected: true,
            enabled: enabled,
            onTap: () => onSelected(selected),
          ),
        for (var i = 0; i < LabelColorPalette.hexColors.length; i++)
          _Swatch(
            swatchKey: Key('label_palette.$i'),
            hex: LabelColorPalette.hexColors[i],
            selected: LabelColorPalette.hexColors[i].toLowerCase() == lower,
            enabled: enabled,
            onTap: () => onSelected(LabelColorPalette.hexColors[i]),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.swatchKey,
    required this.hex,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Key swatchKey;
  final String hex;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 44x44 de área de toque (el círculo visible sigue siendo 38): opaque
    // hace tappable todo el cuadro, no sólo los píxeles pintados.
    return GestureDetector(
      key: swatchKey,
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppTokens.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: LabelDot(hex: hex, size: 28),
          ),
        ),
      ),
    );
  }
}
