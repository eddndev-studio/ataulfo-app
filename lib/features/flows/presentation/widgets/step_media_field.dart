import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../media/domain/entities/media_asset.dart';
import '../../domain/entities/step.dart' as fdom;
import '../media_step_name.dart';

/// Abre un selector de multimedia filtrado por [family] (image|video|audio|
/// document, o null = sin filtro) y devuelve el [MediaAsset] elegido, o `null`
/// si el usuario cancela. El caller persiste el ref BARE canónico
/// (`tenant/<org>/media/<id>[.<ext>]`) — JAMÁS la `previewUrl` firmada efímera —
/// y el filename del asset (para documentos). El `BuildContext` se pasa para que
/// el selector pueda navegar (p. ej. `context.push('/media/pick?type=<family>')`).
typedef MediaRefPicker =
    Future<MediaAsset?> Function(BuildContext context, String? family);

/// Familia de content-type por la que filtrar el picker, derivada del tipo
/// del paso. STICKER usa el contenedor de imagen; AUDIO/PTT comparten audio.
/// DOCUMENT no filtra (null): un paso documento envía cualquier archivo como
/// adjunto descargable, así que el picker ofrece toda la galería (p. ej. para
/// mandar un audio como documento). Los tipos sin media ⇒ null.
String? stepMediaFamilyFor(fdom.StepType type) => switch (type) {
  fdom.StepType.image || fdom.StepType.sticker => 'image',
  fdom.StepType.video => 'video',
  fdom.StepType.audio || fdom.StepType.ptt => 'audio',
  fdom.StepType.document ||
  fdom.StepType.text ||
  fdom.StepType.conditionalTime ||
  fdom.StepType.label ||
  fdom.StepType.end ||
  fdom.StepType.unsupported => null,
};

/// Selector del recurso multimedia del step. El [controller] es la fuente de
/// verdad del `ref` BARE: el gate de submit y el evento de creación leen
/// `controller.text`, no este widget.
///
/// Sin ref: muestra un control tappable (`step_edit.media_picker`) que abre
/// la galería en modo picker vía [pickMediaRef] y guarda el ref devuelto. Con
/// ref: muestra un chip (`step_edit.media_selected`) con una cola corta del
/// ref más un botón "Cambiar" (`step_edit.media_change`) que reabre el picker.
///
/// El widget es read-only cuando [pickMediaRef] es `null` o cuando [enabled]
/// es false (mutación en vuelo): el control no abre nada y el chip no expone
/// "Cambiar". NUNCA renderiza la `previewUrl` ni una miniatura — sólo el ref
/// BARE en texto —, así no arrastra la URL firmada efímera a la UI.
class StepMediaField extends StatelessWidget {
  const StepMediaField({
    super.key,
    required this.controller,
    required this.pickMediaRef,
    required this.family,
    required this.onPicked,
    required this.enabled,
  });

  final TextEditingController controller;
  final MediaRefPicker? pickMediaRef;

  /// Familia de content-type para filtrar la galería-picker (image|video|
  /// audio|document) según el tipo del paso; null ⇒ sin filtro.
  final String? family;

  /// Notifica al padre el asset elegido (para capturar su filename). El ref
  /// BARE va por el [controller]; este callback lleva el resto del asset.
  final ValueChanged<MediaAsset> onPicked;

  final bool enabled;

  bool get _interactive => enabled && pickMediaRef != null;

  Future<void> _pick(BuildContext context) async {
    final picker = pickMediaRef;
    if (picker == null) return;
    final asset = await picker(context, family);
    if (asset == null) return;
    final ref = asset.ref.trim();
    if (ref.isEmpty) return;
    // Setear el texto dispara el listener del controller (en el padre), que
    // hace setState y re-renderiza con el chip seleccionado. El filename viaja
    // por onPicked. NUNCA se persiste asset.previewUrl (firmada efímera).
    controller.text = ref;
    // Asignar `.text` deja la selección en offset -1 (inválida); enfocar el
    // campo seleccionaría todo. Colapsamos el caret al final para poder editar.
    controller.selection = TextSelection.collapsed(offset: ref.length);
    onPicked(asset);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ref = controller.text.trim();
    if (ref.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Recurso',
            style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp2),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.tonal(
              key: const Key('step_edit.media_picker'),
              label: 'Seleccionar multimedia',
              icon: Icons.perm_media_outlined,
              onPressed: _interactive ? () => _pick(context) : null,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Recurso',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp2),
        Container(
          key: const Key('step_edit.media_selected'),
          padding: const EdgeInsets.all(AppTokens.sp3),
          decoration: BoxDecoration(
            color: AppTokens.surface2,
            borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle_outline,
                size: 18,
                color: AppTokens.primary,
              ),
              const SizedBox(width: AppTokens.sp2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Recurso seleccionado', style: textTheme.bodyMedium),
                    const SizedBox(height: AppTokens.sp1),
                    Text(
                      // Cola corta del ref (display-only). La fuente de verdad
                      // sigue siendo el ref BARE completo en el controller.
                      shortMediaRef(ref),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: AppTokens.text2,
                      ),
                    ),
                  ],
                ),
              ),
              if (_interactive)
                AppButton.text(
                  key: const Key('step_edit.media_change'),
                  label: 'Cambiar',
                  onPressed: () => _pick(context),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
