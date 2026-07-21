import 'package:flutter/material.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/i18n/role_labels.dart';
import '../../../bots/domain/entities/bot.dart';

/// Lo que la hoja devuelve al enviarse: a quién invitar y con qué rol. La hoja
/// NO conoce ningún bloc; la página despacha la creación sobre su cubit (la hoja
/// vive en otro subárbol del Navigator).
class InviteSheetResult {
  const InviteSheetResult({
    required this.email,
    required this.role,
    required this.botIds,
  });

  final String email;
  final String role;
  final List<String> botIds;
}

/// Hoja para emitir una invitación: correo + rol. El correo viaja recortado; el
/// backend es la autoridad sobre su validez (un correo inválido vuelve como
/// 422). El rol arranca en WORKER (el invitado más común) y se puede cambiar.
class InviteSheet extends StatefulWidget {
  const InviteSheet({super.key, required this.bots});

  final List<Bot> bots;

  // OWNER se excluye a propósito: aceptar una invitación OWNER mintearía un
  // segundo propietario saltando el flujo deliberado de transferir propiedad.
  // La propiedad se pasa desde /members (transferir), no se invita.
  static const List<String> roleOptions = <String>[
    'ADMIN',
    'SUPERVISOR',
    'WORKER',
  ];

  /// Abre la hoja y resuelve con los datos de la invitación, o `null` si se
  /// descartó sin enviar.
  static Future<InviteSheetResult?> open(
    BuildContext context, {
    required List<Bot> bots,
  }) {
    return showAppBottomSheet<InviteSheetResult>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => InviteSheet(bots: bots),
    );
  }

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  late final TextEditingController _emailCtrl;
  String _role = 'WORKER';
  final Set<String> _selectedBotIds = <String>{};

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController()..addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _emailCtrl
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  /// Forma mínima de email: algo@algo.punto-algo, sin terminar en punto.
  /// El veredicto final es del backend; este gate sólo evita el round-trip
  /// de un typo obvio.
  static final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s.]+$');

  bool get _canSubmit => _emailShape.hasMatch(_emailCtrl.text.trim());

  void _submit() {
    if (!_canSubmit) return;
    final botIds = _role == 'WORKER'
        ? (_selectedBotIds.toList(growable: false)..sort())
        : const <String>[];
    Navigator.of(context).pop(
      InviteSheetResult(
        email: _emailCtrl.text.trim(),
        role: _role,
        botIds: botIds,
      ),
    );
  }

  void _selectRole(String role) {
    setState(() {
      _role = role;
      if (role != 'WORKER') _selectedBotIds.clear();
    });
  }

  void _selectBot(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedBotIds.add(id);
      } else {
        _selectedBotIds.remove(id);
      }
    });
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
          Text('Invitar a la organización', style: textTheme.titleLarge),
          const SizedBox(height: AppTokens.sp5),
          AppTextField(
            key: const Key('invite.email'),
            label: 'Correo',
            hint: 'persona@empresa.com',
            controller: _emailCtrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppTokens.sp4),
          Text(
            'Rol',
            style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp1),
          // Set cerrado y corto: chips a la vista (selección única), no un
          // dropdown que esconde las opciones tras un tap.
          Wrap(
            key: const Key('invite.role'),
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final r in InviteSheet.roleOptions)
                AppChoiceChip(
                  label: roleLabel(r),
                  selected: r == _role,
                  onSelected: (_) => _selectRole(r),
                ),
            ],
          ),
          if (_role == 'WORKER') ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            Text(
              'Canales que puede atender',
              style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp1),
            Column(
              key: const Key('invite.channels'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (widget.bots.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final bot in widget.bots)
                        AppChoiceChip(
                          label: bot.name,
                          selected: _selectedBotIds.contains(bot.id),
                          onSelected: (selected) =>
                              _selectBot(bot.id, selected),
                        ),
                    ],
                  ),
                if (widget.bots.isNotEmpty && _selectedBotIds.isEmpty) ...[
                  const SizedBox(height: AppTokens.sp2),
                  Text(
                    'Sin selección, el Agente entrará sin acceso a Canales.',
                    key: const Key('invite.channels.warning'),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTokens.warning,
                    ),
                  ),
                ],
                if (widget.bots.isEmpty)
                  Text(
                    'No hay Canales disponibles. El Agente entrará con acceso '
                    'cero hasta que le asignes uno.',
                    key: const Key('invite.channels.warning'),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTokens.warning,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppTokens.sp5),
          AppButton.filled(
            key: const Key('invite.submit'),
            label: 'Enviar invitación',
            fullWidth: true,
            onPressed: _canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }
}
