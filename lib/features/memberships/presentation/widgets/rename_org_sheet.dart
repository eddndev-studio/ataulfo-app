import 'package:flutter/material.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';

/// Hoja para renombrar la organización activa. DEVUELVE el nombre nuevo al
/// cerrarse (o `null` si se descartó); la página despacha el rename sobre su
/// `RenameOrgCubit` y recarga el nombre fresco. No conoce ningún bloc: la hoja
/// vive en otro subárbol del Navigator.
class RenameOrgSheet extends StatefulWidget {
  const RenameOrgSheet({super.key, required this.currentName});

  final String currentName;

  /// Abre la hoja y resuelve con el nombre nuevo, o `null` si no se cambió.
  static Future<String?> open(
    BuildContext context, {
    required String currentName,
  }) {
    return showAppBottomSheet<String>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => RenameOrgSheet(currentName: currentName),
    );
  }

  @override
  State<RenameOrgSheet> createState() => _RenameOrgSheetState();
}

class _RenameOrgSheetState extends State<RenameOrgSheet> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentName)
      ..addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  /// Habilitado sólo si hay un nombre no-vacío Y distinto del actual (renombrar
  /// al mismo nombre no tiene efecto).
  bool get _canSubmit {
    final trimmed = _nameCtrl.text.trim();
    return trimmed.isNotEmpty && trimmed != widget.currentName.trim();
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(_nameCtrl.text.trim());
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Renombrar organización', style: textTheme.titleLarge),
          const SizedBox(height: AppTokens.sp5),
          AppTextField(
            key: const Key('rename_org.name'),
            label: 'Nombre',
            hint: 'Mi empresa',
            controller: _nameCtrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppTokens.sp5),
          AppButton.filled(
            key: const Key('rename_org.submit'),
            label: 'Guardar',
            fullWidth: true,
            onPressed: _canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }
}
