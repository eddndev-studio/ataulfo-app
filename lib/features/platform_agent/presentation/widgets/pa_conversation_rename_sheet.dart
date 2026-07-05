import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';

/// Form-sheet para renombrar una conversación del asistente. Sigue la anatomía
/// de sheets del kit (título + [AppTextField] + Guardar a ancho completo) en vez
/// de un `AlertDialog` crudo. Es un [StatefulWidget] para que el controller viva
/// y se libere con el ciclo del sheet. Hace pop con el título recortado al
/// guardar, o sin valor si se descarta; el llamador decide si aplicar el cambio.
class PaConversationRenameSheet extends StatefulWidget {
  const PaConversationRenameSheet({super.key, required this.initial});

  final String initial;

  /// Abre el sheet canónico (surface1) prefijado con [initial] y resuelve con el
  /// título elegido (recortado), o `null` si se descartó sin guardar.
  static Future<String?> open(BuildContext context, {required String initial}) {
    return showAppBottomSheet<String>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => PaConversationRenameSheet(initial: initial),
    );
  }

  @override
  State<PaConversationRenameSheet> createState() =>
      _PaConversationRenameSheetState();
}

class _PaConversationRenameSheetState extends State<PaConversationRenameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
          Text('Renombrar conversación', style: textTheme.titleLarge),
          const SizedBox(height: AppTokens.sp5),
          AppTextField(
            key: const Key('pa.history.rename.field'),
            label: 'Nombre',
            hint: 'Nombre de la conversación',
            controller: _controller,
            autofocus: true,
            inputFormatters: <TextInputFormatter>[
              LengthLimitingTextInputFormatter(200),
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppTokens.sp5),
          AppButton.filled(
            key: const Key('pa.history.rename.confirm'),
            label: 'Guardar',
            fullWidth: true,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
