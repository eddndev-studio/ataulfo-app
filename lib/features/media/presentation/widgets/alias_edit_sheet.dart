import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';

/// Form-sheet de edición del alias de un asset. Es un StatefulWidget para que
/// el [TextEditingController] viva y se libere con el ciclo del sheet
/// (disponerlo fuera de su `dispose` corre la carrera de usarlo tras liberarlo
/// durante el teardown). Hace pop con el texto al guardar, o sin valor al
/// descartarse; un alias vacío limpia el nombre amistoso (vuelve al filename).
class AliasEditSheet extends StatefulWidget {
  const AliasEditSheet({super.key, required this.initial});

  final String initial;

  /// Abre el form-sheet canónico (surface1) prefijado con [initial] y resuelve
  /// con el alias elegido, o `null` si se descartó sin guardar.
  static Future<String?> open(BuildContext context, {required String initial}) {
    return showAppBottomSheet<String>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => AliasEditSheet(initial: initial),
    );
  }

  @override
  State<AliasEditSheet> createState() => _AliasEditSheetState();
}

class _AliasEditSheetState extends State<AliasEditSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
          Text('Renombrar', style: textTheme.titleLarge),
          const SizedBox(height: AppTokens.sp5),
          AppTextField(
            key: const Key('media_detail.alias_field'),
            label: 'Alias',
            hint: 'Nombre amistoso (vacío = nombre original)',
            controller: _controller,
            autofocus: true,
            // Mismo tope que persiste el backend para el alias.
            inputFormatters: <TextInputFormatter>[
              LengthLimitingTextInputFormatter(200),
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          const SizedBox(height: AppTokens.sp5),
          AppButton.filled(
            label: 'Guardar',
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(_controller.text),
          ),
        ],
      ),
    );
  }
}
