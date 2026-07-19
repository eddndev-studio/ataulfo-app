import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_action_row.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/workspace_doc.dart';
import '../bloc/workspace_bloc.dart';
import 'trainer_chat_page.dart' show trainerFailureCopy;
import '../widgets/workspace_doc_sheet.dart';

/// Cap del adjunto (texto) — espejo del acordado en la spec del arco; el
/// servidor además enforza su propio cap por doc.
const int kAttachMaxBytes = 256 * 1024;

/// Extensiones de texto aceptadas al adjuntar.
const List<String> kAttachExtensions = <String>['txt', 'md', 'csv'];

/// Panel del Workspace de negocio: los documentos que alimentan al bot.
/// CRUD manual + adjuntar archivo de texto (se convierte en doc).
class WorkspacePage extends StatelessWidget {
  const WorkspacePage({required this.templateId, super.key});

  final String templateId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspace del negocio'),
        actions: <Widget>[
          IconButton(
            key: const Key('workspace.attach'),
            tooltip: 'Adjuntar archivo de texto',
            icon: const Icon(Icons.attach_file),
            onPressed: () => _attach(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('workspace.new'),
        tooltip: 'Nuevo documento',
        onPressed: () => WorkspaceDocSheet.openCreate(context),
        child: const Icon(Icons.add),
      ),
      body: BlocConsumer<WorkspaceBloc, WorkspaceState>(
        listener: (context, state) {
          if (state is WorkspaceLoaded && state.mutationFailure != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(trainerFailureCopy(state.mutationFailure!)),
              ),
            );
          }
        },
        builder: (context, state) => switch (state) {
          WorkspaceLoading() => const AppLoadingIndicator(),
          WorkspaceFailed(:final failure) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(trainerFailureCopy(failure)),
                const SizedBox(height: AppTokens.sp3),
                AppButton.filled(
                  label: 'Reintentar',
                  onPressed: () => context.read<WorkspaceBloc>().add(
                    const WorkspaceLoadRequested(),
                  ),
                ),
              ],
            ),
          ),
          WorkspaceLoaded(:final docs) =>
            docs.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Sin documentos todavía. El entrenador (o tú) puede crear aquí los precios, políticas y datos que el bot consulta al responder.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(bottom: context.safeBottomInset),
                    itemCount: docs.length,
                    itemBuilder: (context, i) => _DocTile(doc: docs[i]),
                  ),
        },
      ),
    );
  }

  Future<void> _attach(BuildContext context) async {
    final bloc = context.read<WorkspaceBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kAttachExtensions,
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo.')),
      );
      return;
    }
    if (bytes.length > kAttachMaxBytes) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('El archivo supera el límite de 256 KB para adjuntos.'),
        ),
      );
      return;
    }
    final name = slugifyDocName(file.name);
    if (name.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('El nombre del archivo no es usable.')),
      );
      return;
    }
    bloc.add(
      WorkspaceDocCreated(name: name, content: String.fromCharCodes(bytes)),
    );
  }
}

/// Slug espejo de las reglas del dominio knowledge (minúsculas, acentos
/// plegados, separadores a guion, 64 máx). El servidor valida igual: esto
/// solo evita el 422 evitable.
String slugifyDocName(String input) {
  const folded = <String, String>{
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  final base = input.contains('.')
      ? input.substring(0, input.lastIndexOf('.'))
      : input;
  final buf = StringBuffer();
  var lastHyphen = true;
  for (final rune in base.toLowerCase().runes) {
    var ch = String.fromCharCode(rune);
    ch = folded[ch] ?? ch;
    final isAlnum = RegExp(r'^[a-z0-9]$').hasMatch(ch);
    if (isAlnum) {
      buf.write(ch);
      lastHyphen = false;
    } else if (!lastHyphen) {
      buf.write('-');
      lastHyphen = true;
    }
  }
  var out = buf.toString();
  while (out.endsWith('-')) {
    out = out.substring(0, out.length - 1);
  }
  if (out.length > 64) {
    out = out.substring(0, 64);
    while (out.endsWith('-')) {
      out = out.substring(0, out.length - 1);
    }
  }
  return out;
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.doc});

  final WorkspaceDoc doc;

  String get _size {
    if (doc.sizeBytes < 1024) return '${doc.sizeBytes} B';
    return '${(doc.sizeBytes / 1024).toStringAsFixed(1)} KB';
  }

  @override
  Widget build(BuildContext context) {
    return AppActionRow(
      key: Key('workspace.doc.${doc.name}'),
      icon: Icons.description_outlined,
      title: doc.name,
      subtitle: _size,
      trailing: doc.updatedByTrainer
          ? AppPill.primary(
              key: Key('workspace.badge.${doc.name}'),
              label: 'Entrenador',
            )
          : null,
      onTap: () => WorkspaceDocSheet.openExisting(context, name: doc.name),
    );
  }
}
