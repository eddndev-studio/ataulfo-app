import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/note.dart';
import '../../domain/failures/notes_failure.dart';
import '../../domain/repositories/notes_repository.dart';
import '../bloc/notes_bloc.dart';
import 'note_edit_sheet.dart';

/// Panel de notas del chat (S14). Lista el cuaderno anclado a (bot, chat) —
/// notas del operador Y del agente IA (badge "IA") — y permite crear, editar
/// y borrar. Mismo cuaderno que escribe el builtin `save_note` del agente.
///
/// Crea su propio `NotesBloc` leyendo el `NotesRepository` del scope (lo
/// provee la ruta del hilo). Tap en una nota abre el editor; "+ Nueva" el
/// alta.
class NotesSheet extends StatelessWidget {
  const NotesSheet({super.key});

  static void open(
    BuildContext context, {
    required String botId,
    required String chatLid,
  }) {
    final repo = context.read<NotesRepository>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<NotesBloc>(
        create: (_) => NotesBloc(repo: repo, botId: botId, chatLid: chatLid)
          ..add(const NotesLoadRequested()),
        child: const NotesSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesBloc, NotesState>(
      builder: (context, state) => switch (state) {
        NotesLoading() => const _LoadingView(),
        NotesLoaded(:final notes) => _Body(notes: notes, failure: null),
        NotesMutating(:final notes) => _Body(
          notes: notes,
          failure: null,
          isMutating: true,
        ),
        NotesMutationFailed(:final notes, :final failure) => _Body(
          notes: notes,
          failure: failure,
        ),
        NotesFailed(:final failure) => _FailedView(failure: failure),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppTokens.sp8),
    child: Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
      ),
    ),
  );
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final NotesFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6 + context.safeBottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'No pudimos cargar las notas de este chat.',
            key: const Key('notes_sheet.failed'),
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
          ),
          const SizedBox(height: AppTokens.sp4),
          AppButton.tonal(
            key: const Key('notes_sheet.retry'),
            label: 'Reintentar',
            onPressed: () =>
                context.read<NotesBloc>().add(const NotesLoadRequested()),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.notes,
    required this.failure,
    this.isMutating = false,
  });

  final List<Note> notes;
  final NotesFailure? failure;
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp6,
          AppTokens.sp6,
          AppTokens.sp6,
          AppTokens.sp4 + context.safeBottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Notas del chat', style: textTheme.titleMedium),
                AppButton.tonal(
                  key: const Key('notes_sheet.new_button'),
                  label: 'Nueva',
                  onPressed: isMutating
                      ? null
                      : () => NoteEditSheet.open(context),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.sp4),
            if (failure != null) ...<Widget>[
              Text(
                _failureCopy(failure!),
                key: const Key('notes_sheet.error'),
                style: textTheme.bodySmall?.copyWith(color: AppTokens.danger),
              ),
              const SizedBox(height: AppTokens.sp3),
            ],
            if (isMutating) ...<Widget>[
              const SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
                ),
              ),
              const SizedBox(height: AppTokens.sp3),
            ],
            if (notes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTokens.sp6),
                child: Text(
                  'Sin notas todavía. Guarda acuerdos, preferencias o '
                  'contexto del cliente — el agente IA también las lee.',
                  key: const Key('notes_sheet.empty'),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTokens.text2,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: notes.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTokens.sp3),
                  itemBuilder: (context, i) => _NoteCard(
                    note: notes[i],
                    onTap: isMutating
                        ? null
                        : () => NoteEditSheet.open(context, note: notes[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _failureCopy(NotesFailure f) => switch (f) {
    NotesConflictFailure() =>
      'Otro editor (operador o IA) cambió esa nota. Recarga e intenta de nuevo.',
    NotesValidationFailure() =>
      'La nota no es válida: revisa el contenido y las etiquetas.',
    NotesForbiddenFailure() => 'Tu rol no permite editar notas de este chat.',
    NotesNotFoundFailure() => 'Esa nota ya no existe.',
    NotesNetworkFailure() ||
    NotesTimeoutFailure() => 'Sin conexión con el servidor. Reintenta.',
    NotesServerFailure() => 'El servidor falló al guardar. Reintenta.',
    NotesUnknownFailure() => 'No pudimos guardar la nota. Reintenta.',
  };
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});

  final Note note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      key: Key('notes_sheet.card.${note.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (note.color.isNotEmpty) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: AppTokens.sp1),
                  child: _ColorDot(hex: note.color),
                ),
                const SizedBox(width: AppTokens.sp2),
              ],
              Expanded(
                child: Text(note.content, style: textTheme.bodyMedium),
              ),
              if (note.isAiCreated) ...<Widget>[
                const SizedBox(width: AppTokens.sp2),
                AppPill.primary(
                  key: Key('notes_sheet.ai_badge.${note.id}'),
                  label: 'IA',
                ),
              ],
            ],
          ),
          if (note.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppTokens.sp2),
            Wrap(
              spacing: AppTokens.sp2,
              runSpacing: AppTokens.sp2,
              children: <Widget>[
                for (final t in note.tags) AppPill.neutral(label: t),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.hex});

  final String hex;

  @override
  Widget build(BuildContext context) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    final color = value == null
        ? AppTokens.surface3
        : Color(0xFF000000 | value);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
