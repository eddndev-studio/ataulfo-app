import 'package:flutter/material.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/member.dart';

/// Resultado que la hoja devuelve al cerrarse. La hoja NO conoce ningún bloc:
/// devuelve la intención y la página la despacha sobre el `MemberMutationCubit`
/// de su scope (la hoja vive en otro subárbol del Navigator, donde el cubit no
/// está provisto).
sealed class MemberSheetResult {
  const MemberSheetResult();
}

/// El admin eligió un rol nuevo y confirmó. [role] viaja uppercase del set
/// cerrado del backend.
final class MemberSheetRoleChange extends MemberSheetResult {
  const MemberSheetRoleChange(this.role);

  final String role;
}

/// El admin confirmó quitar al miembro de la organización.
final class MemberSheetRemove extends MemberSheetResult {
  const MemberSheetRemove();
}

/// Hoja de gestión de un miembro: cambiar su rol o quitarlo de la organización.
///
/// El picker ofrece el set completo de roles; el backend es la autoridad sobre
/// qué transición se permite (rechaza self-upgrade y dejar a la org sin owner).
/// Por eso el cliente no recorta el dropdown por rango del caller. "Quitar" se
/// oculta en la propia fila ([isSelf]): auto-quitarse revoca la sesión, lo que
/// haría caer al operador fuera de la app.
class MemberEditSheet extends StatefulWidget {
  const MemberEditSheet({
    super.key,
    required this.member,
    required this.isSelf,
  });

  final Member member;
  final bool isSelf;

  static const List<String> roleOptions = <String>[
    'OWNER',
    'ADMIN',
    'SUPERVISOR',
    'WORKER',
  ];

  /// Abre la hoja y resuelve con la intención elegida, o `null` si se descartó.
  static Future<MemberSheetResult?> open(
    BuildContext context, {
    required Member member,
    required bool isSelf,
  }) {
    return showModalBottomSheet<MemberSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => MemberEditSheet(member: member, isSelf: isSelf),
    );
  }

  @override
  State<MemberEditSheet> createState() => _MemberEditSheetState();
}

class _MemberEditSheetState extends State<MemberEditSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.member.role;
  }

  bool get _changed => _selected != widget.member.role;

  void _save() {
    if (!_changed) return;
    Navigator.of(context).pop(MemberSheetRoleChange(_selected));
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar a este miembro?'),
        content: Text(
          'Perderá el acceso a "${widget.member.email}" en esta organización y '
          'su sesión se cerrará al instante. Esta acción no se puede deshacer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('member_edit.remove_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Quitar',
              style: TextStyle(color: AppTokens.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop(const MemberSheetRemove());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final items = MemberEditSheet.roleOptions
        .map((r) => DropdownMenuItem<String>(value: r, child: Text(r)))
        .toList(growable: false);
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
          Text(widget.member.email, style: textTheme.titleLarge),
          const SizedBox(height: AppTokens.sp2),
          Row(
            children: <Widget>[
              const Text('Rol actual'),
              const SizedBox(width: AppTokens.sp3),
              AppPill.neutral(label: widget.member.role),
            ],
          ),
          const SizedBox(height: AppTokens.sp5),
          Text(
            'Rol',
            style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp1),
          DropdownButtonFormField<String>(
            key: const Key('member_edit.role'),
            initialValue: items.any((i) => i.value == _selected)
                ? _selected
                : null,
            items: items,
            onChanged: (v) {
              if (v != null) setState(() => _selected = v);
            },
          ),
          const SizedBox(height: AppTokens.sp5),
          AppButton.filled(
            key: const Key('member_edit.save'),
            label: 'Guardar rol',
            fullWidth: true,
            onPressed: _changed ? _save : null,
          ),
          if (!widget.isSelf) ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            AppButton.danger(
              key: const Key('member_edit.remove'),
              label: 'Quitar de la organización',
              fullWidth: true,
              onPressed: _confirmRemove,
            ),
          ],
        ],
      ),
    );
  }
}
