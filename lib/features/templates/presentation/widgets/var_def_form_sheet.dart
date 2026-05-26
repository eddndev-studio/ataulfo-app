import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/variable_def.dart';
import '../bloc/var_defs_bloc.dart';

/// Modal sheet de creación o edición de una variable-definition.
///
/// Vive sobre el `TemplateDetailPage` que aporta el `VarDefsBloc`. La
/// lista de `existingNames` se pasa explícita para el pre-flight inline
/// de nombres duplicados — el server 409 sigue siendo source of truth
/// (race contra otro operador), pero el hint avisa lo común sin la ida.
///
/// `editing == null` ⇒ modo creación (POST). `editing != null` ⇒ modo
/// edición: fields pre-fillados con los valores actuales, dup hint
/// excluye el mismo name original, submit dispatcha UpdateRequested
/// only-changed (campos sin cambio no viajan al backend).
///
/// El sheet escucha el `VarDefsBloc`:
/// - Mutating ⇒ submit bloqueado con loading.
/// - Loaded post-submit ⇒ auto-pop del sheet (flag `_didSubmit` evita
///   cerrar por rebuilds incidentales sin haber disparado nada).
/// - MutationFailed ⇒ sheet sigue montado para que el operador corrija
///   y reintente desde el mismo form; el snackbar lo monta la página
///   padre con su propio BlocListener.
class VarDefFormSheet extends StatefulWidget {
  const VarDefFormSheet({
    super.key,
    required this.existingNames,
    this.editing,
  });

  /// Nombres que ya viven en la Template; usados para el pre-flight
  /// inline. Pasarlos como prop (en vez de leerlos del bloc) mantiene
  /// el widget puro y testeable con un Set fijo.
  ///
  /// En modo edit el caller debe incluir TODOS los nombres (incluyendo
  /// el del editing) — el sheet excluye el del editing internamente al
  /// evaluar duplicados.
  final Set<String> existingNames;

  /// `null` ⇒ modo creación. No-null ⇒ modo edición; los fields se
  /// pre-llenan con los valores actuales y el submit dispatcha
  /// UpdateRequested only-changed.
  final VariableDef? editing;

  @override
  State<VarDefFormSheet> createState() => _VarDefFormSheetState();
}

class _VarDefFormSheetState extends State<VarDefFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _defaultCtrl;
  late final TextEditingController _descCtrl;

  /// Flag de "ya disparé un submit, esperando el Loaded final".
  /// Sin esto, cualquier rebuild del bloc a Loaded cerraría el sheet
  /// (p.ej. el Loaded inicial al montar, o un refetch externo).
  bool _didSubmit = false;

  @override
  void initState() {
    super.initState();
    final ed = widget.editing;
    _nameCtrl = TextEditingController(text: ed?.name ?? '');
    _defaultCtrl = TextEditingController(text: ed?.defaultValue ?? '');
    _descCtrl = TextEditingController(text: ed?.description ?? '');
    // Re-build el sheet cuando el name cambia: gate del submit + hint
    // de duplicado dependen de `_nameCtrl.text`. Listener sobre los
    // otros dos controllers no aporta nada al render.
    _nameCtrl.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _defaultCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final ed = widget.editing;
    if (ed == null) {
      _didSubmit = true;
      context.read<VarDefsBloc>().add(
        VarDefsAddRequested(
          name: name,
          type: VarType.text,
          defaultValue: _defaultCtrl.text,
          description: _descCtrl.text,
        ),
      );
      return;
    }

    // Modo edit: only-changed. Construir el patch comparando cada campo
    // contra el editing original. Si nada cambió, el submit es no-op
    // (la UI evita request inútil; el server-side ya sería no-op de
    // todos modos pero gasta round-trip).
    final newName = name != ed.name ? name : null;
    final newDefault =
        _defaultCtrl.text != ed.defaultValue ? _defaultCtrl.text : null;
    final newDesc = _descCtrl.text != ed.description ? _descCtrl.text : null;
    final isNoOp = newName == null && newDefault == null && newDesc == null;
    if (isNoOp) return;

    _didSubmit = true;
    context.read<VarDefsBloc>().add(
      VarDefsUpdateRequested(
        varDefId: ed.id,
        name: newName,
        defaultValue: newDefault,
        description: newDesc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ed = widget.editing;
    final isEditing = ed != null;
    return BlocListener<VarDefsBloc, VarDefsState>(
      listener: (context, state) {
        if (_didSubmit && state is VarDefsLoaded) {
          Navigator.of(context).maybePop();
        }
      },
      child: BlocBuilder<VarDefsBloc, VarDefsState>(
        builder: (context, state) {
          final isMutating = state is VarDefsMutating;
          final name = _nameCtrl.text.trim();
          // En modo edit, el name del editing original NO cuenta como
          // duplicado de sí mismo. Excluimos su name del check.
          final isDuplicate =
              name.isNotEmpty &&
              widget.existingNames.contains(name) &&
              (ed == null || name != ed.name);
          // El sheet sube con el teclado virtual; padding inferior
          // dinámico evita que el campo activo quede oculto.
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppTokens.sp6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    isEditing ? 'Editar variable' : 'Nueva variable',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppTokens.sp4),
                  AppTextField(
                    key: const Key('var_def_form.name'),
                    label: 'Nombre',
                    hint: 'saldo, nombre, id…',
                    controller: _nameCtrl,
                    enabled: !isMutating,
                    autofocus: true,
                  ),
                  if (isDuplicate)
                    Padding(
                      key: const Key('var_def_form.dup_hint'),
                      padding: const EdgeInsets.only(top: AppTokens.sp1),
                      child: Text(
                        'Ya existe una variable con ese nombre.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTokens.danger,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppTokens.sp4),
                  AppTextField(
                    key: const Key('var_def_form.default'),
                    label: 'Valor por defecto',
                    hint: 'Usado cuando el bot no recibe valor',
                    controller: _defaultCtrl,
                    enabled: !isMutating,
                  ),
                  const SizedBox(height: AppTokens.sp4),
                  AppTextField(
                    key: const Key('var_def_form.description'),
                    label: 'Descripción',
                    hint: 'Qué representa esta variable (opcional)',
                    controller: _descCtrl,
                    enabled: !isMutating,
                  ),
                  const SizedBox(height: AppTokens.sp6),
                  AppButton.filled(
                    key: const Key('var_def_form.submit'),
                    label: 'Guardar',
                    onPressed: name.isEmpty ? null : _submit,
                    loading: isMutating,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
