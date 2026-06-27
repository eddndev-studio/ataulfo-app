import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
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
  const WorkspaceDocSheet._({required this.name});

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
      builder: (_) => MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<WorkspaceBloc>.value(value: bloc),
        ],
        child: RepositoryProvider<WorkspaceRepository>.value(
          value: repo,
          child: WorkspaceDocSheet._(name: name),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: name == null
          ? const _DocForm(doc: null)
          : _ExistingDocLoader(name: name!),
    );
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
            padding: const EdgeInsets.all(24),
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
            child: Center(child: CircularProgressIndicator()),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('¿Borrar documento?'),
        content: Text(
          'El bot dejará de poder consultar "${doc.name}". Esta acción es definitiva.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('workspace_doc.delete_confirm'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    bloc.add(WorkspaceDocDeleted(name: doc.name, version: doc.version));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.doc == null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              isNew ? 'Nuevo documento' : widget.doc!.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (isNew) ...<Widget>[
              TextField(
                key: const Key('workspace_doc.name'),
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nombre (ej. menu-precios)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: TextField(
                key: const Key('workspace_doc.content'),
                controller: _content,
                maxLines: null,
                minLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Contenido',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                if (!isNew)
                  TextButton(
                    key: const Key('workspace_doc.delete'),
                    onPressed: _delete,
                    child: const Text('Borrar'),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('workspace_doc.save'),
                  onPressed: _save,
                  child: Text(isNew ? 'Crear' : 'Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
