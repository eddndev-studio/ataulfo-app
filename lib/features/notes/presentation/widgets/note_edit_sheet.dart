import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../labels/presentation/widgets/label_color_palette.dart';
import '../../domain/entities/note.dart';
import '../bloc/notes_bloc.dart';

/// Editor de una nota del chat: alta (`note == null`) o edición. Despacha
/// los eventos sobre el `NotesBloc` del sheet padre y se cierra — el panel
/// refleja el resultado (Mutating → recarga) o el copy de fallo.
class NoteEditSheet extends StatefulWidget {
  const NoteEditSheet({super.key, this.note});

  final Note? note;

  /// Abre el editor como modal anidado conservando el `NotesBloc` del
  /// contexto del panel.
  static void open(BuildContext context, {Note? note}) {
    final bloc = context.read<NotesBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<NotesBloc>.value(
        value: bloc,
        child: NoteEditSheet(note: note),
      ),
    );
  }

  @override
  State<NoteEditSheet> createState() => _NoteEditSheetState();
}

class _NoteEditSheetState extends State<NoteEditSheet> {
  late final TextEditingController _contentCtrl;
  late final TextEditingController _tagsCtrl;
  late String _color;

  bool get _isEdit => widget.note != null;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: widget.note?.content ?? '');
    _tagsCtrl = TextEditingController(
      text: widget.note == null ? '' : widget.note!.tags.join(', '),
    );
    _color = widget.note?.color ?? '';
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  /// Tags del campo coma-separado, normalizadas como el backend S14:
  /// trim + lowercase + dedupe en orden de aparición, vacíos fuera.
  List<String> _parsedTags() {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in _tagsCtrl.text.split(',')) {
      final t = raw.trim().toLowerCase();
      if (t.isEmpty || seen.contains(t)) continue;
      seen.add(t);
      out.add(t);
    }
    return out;
  }

  void _save() {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) return;
    final bloc = context.read<NotesBloc>();
    final note = widget.note;
    if (note == null) {
      bloc.add(
        NotesCreateRequested(
          content: content,
          tags: _parsedTags(),
          color: _color,
        ),
      );
    } else {
      bloc.add(
        NotesUpdateRequested(
          id: note.id,
          version: note.version,
          content: content,
          tags: _parsedTags(),
          color: _color,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  void _delete() {
    final note = widget.note!;
    context.read<NotesBloc>().add(
      NotesDeleteRequested(id: note.id, version: note.version),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    return Padding(
      // El inset del teclado para que el form no quede tapado al escribir.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp6,
          AppTokens.sp6,
          AppTokens.sp6,
          AppTokens.sp6 + context.safeBottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _isEdit ? 'Editar nota' : 'Nueva nota',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.sp4),
            AppTextField(
              key: const Key('note_edit.content'),
              label: 'Nota',
              hint: 'Acuerdos, preferencias, contexto del cliente…',
              controller: _contentCtrl,
              minLines: 4,
              maxLines: null,
            ),
            const SizedBox(height: AppTokens.sp4),
            AppTextField(
              key: const Key('note_edit.tags'),
              label: 'Etiquetas (separadas por comas)',
              hint: 'ventas, urgente…',
              controller: _tagsCtrl,
            ),
            const SizedBox(height: AppTokens.sp4),
            Text(
              'Color',
              style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp2),
            _ColorPicker(
              selected: _color,
              onChanged: (hex) => setState(() => _color = hex),
            ),
            const SizedBox(height: AppTokens.sp6),
            AppButton.filled(
              key: const Key('note_edit.save'),
              label: 'Guardar',
              onPressed: _save,
              fullWidth: true,
            ),
            if (_isEdit) ...<Widget>[
              const SizedBox(height: AppTokens.sp3),
              AppButton.tonal(
                key: const Key('note_edit.delete'),
                label: 'Borrar nota',
                onPressed: _delete,
                fullWidth: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Swatches de la paleta compartida + "sin color" al frente. Reusa la
/// paleta curada de Labels: mismo lenguaje visual en todo el producto.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.sp2,
      runSpacing: AppTokens.sp2,
      children: <Widget>[
        _Swatch(
          key: const Key('note_edit.color.none'),
          color: null,
          isSelected: selected.isEmpty,
          onTap: () => onChanged(''),
        ),
        for (final hex in LabelColorPalette.hexColors)
          _Swatch(
            key: Key('note_edit.color.$hex'),
            color: _parse(hex),
            isSelected: selected == hex,
            onTap: () => onChanged(hex),
          ),
      ],
    );
  }

  static Color _parse(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0;
    return Color(0xFF000000 | value);
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  /// `null` = sin color (swatch tachado).
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color ?? AppTokens.surface2,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTokens.primary : AppTokens.surface3,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: color == null
            ? const Icon(Icons.block, size: 14, color: AppTokens.text2)
            : null,
      ),
    );
  }
}
