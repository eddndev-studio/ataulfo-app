import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/workspace_doc.dart';
import '../../domain/failures/trainer_failure.dart';
import '../../domain/repositories/trainer_repositories.dart';
import '../bloc/workspace_bloc.dart';
import '../pages/trainer_chat_page.dart' show trainerFailureCopy;

/// Hoja de detalle/edición de un doc del workspace. Para uno existente
/// carga el contenido completo (el listado viaja sin content); para uno
/// nuevo pide nombre + contenido. Guardar despacha al WorkspaceBloc del
/// padre (mutación→recarga); borrar pide confirmación.
class WorkspaceDocSheet extends StatelessWidget {
  const WorkspaceDocSheet({super.key, this.name});

  /// `null` ⇒ modo creación; no-null ⇒ nombre del doc existente a cargar.
  final String? name;

  static Future<void> openCreate(BuildContext context) => _open(context, null);

  static Future<void> openExisting(
    BuildContext context, {
    required String name,
  }) => _open(context, name);

  static Future<void> _open(BuildContext context, String? name) {
    final bloc = context.read<WorkspaceBloc>();
    final repo = context.read<WorkspaceRepository>();
    return showAppBottomSheet<void>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<WorkspaceBloc>.value(value: bloc),
        ],
        child: RepositoryProvider<WorkspaceRepository>.value(
          value: repo,
          child: WorkspaceDocSheet(name: name),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = name;
    return n == null ? const _DocForm(doc: null) : _ExistingDocLoader(name: n);
  }
}

class _ExistingDocLoader extends StatefulWidget {
  const _ExistingDocLoader({required this.name});

  final String name;

  @override
  State<_ExistingDocLoader> createState() => _ExistingDocLoaderState();
}

class _ExistingDocLoaderState extends State<_ExistingDocLoader> {
  late final Future<WorkspaceDoc> _future;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<WorkspaceBloc>();
    _future = context.read<WorkspaceRepository>().getDoc(
      templateId: bloc.templateId,
      name: widget.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WorkspaceDoc>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          final err = snap.error;
          return Padding(
            padding: const EdgeInsets.all(AppTokens.sp6),
            child: Text(
              err is TrainerFailure
                  ? trainerFailureCopy(err)
                  : 'No se pudo cargar el documento.',
            ),
          );
        }
        if (!snap.hasData) {
          return const SizedBox(
            height: 160,
            child: Center(child: AppLoadingIndicator()),
          );
        }
        return _DocForm(doc: snap.data);
      },
    );
  }
}

class _DocForm extends StatefulWidget {
  const _DocForm({required this.doc});

  final WorkspaceDoc? doc;

  @override
  State<_DocForm> createState() => _DocFormState();
}

class _DocFormState extends State<_DocForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.doc?.name ?? '',
  );
  late final TextEditingController _content = TextEditingController(
    text: widget.doc?.content ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _content.dispose();
    super.dispose();
  }

  void _save() {
    final bloc = context.read<WorkspaceBloc>();
    final doc = widget.doc;
    if (doc == null) {
      bloc.add(
        WorkspaceDocCreated(name: _name.text.trim(), content: _content.text),
      );
    } else {
      bloc.add(
        WorkspaceDocUpdated(
          name: doc.name,
          content: _content.text,
          version: doc.version,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final doc = widget.doc;
    if (doc == null) return;
    final bloc = context.read<WorkspaceBloc>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: '¿Borrar documento?',
      message:
          'El bot dejará de poder consultar "${doc.name}". Esta acción es '
          'definitiva.',
      confirmLabel: 'Borrar',
      confirmKey: const Key('workspace_doc.delete_confirm'),
    );
    if (!confirmed || !mounted) return;
    bloc.add(WorkspaceDocDeleted(name: doc.name, version: doc.version));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isNew = widget.doc == null;
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
                  isNew ? 'Nuevo documento' : widget.doc!.name,
                  style: textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isNew)
                IconButton(
                  key: const Key('workspace_doc.delete'),
                  tooltip: 'Borrar documento',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppTokens.danger,
                  ),
                  onPressed: _delete,
                ),
            ],
          ),
          const SizedBox(height: AppTokens.sp4),
          if (isNew) ...<Widget>[
            AppTextField(
              key: const Key('workspace_doc.name'),
              label: 'Nombre',
              hint: 'menu-precios',
              controller: _name,
              autofocus: true,
            ),
            const SizedBox(height: AppTokens.sp4),
          ],
          // Un doc es un texto largo: piso de 6 líneas, techo de 12 y scroll
          // interno más allá (el techo evita que el CTA salga de pantalla).
          AppTextField(
            key: const Key('workspace_doc.content'),
            label: 'Contenido',
            hint: 'Lo que el bot podrá consultar de este documento',
            controller: _content,
            minLines: 6,
            maxLines: 12,
          ),
          const SizedBox(height: AppTokens.sp6),
          AppButton.filled(
            key: const Key('workspace_doc.save'),
            label: isNew ? 'Crear' : 'Guardar',
            onPressed: _save,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}
