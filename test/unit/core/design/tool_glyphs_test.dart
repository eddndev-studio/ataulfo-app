import 'package:ataulfo/core/design/tool_glyphs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toolTitleFor', () {
    test('nombra las lecturas del asistente en es-MX', () {
      expect(toolTitleFor('list_bots'), 'Consultó los bots');
      expect(toolTitleFor('get_flow'), 'Consultó un flujo');
    });

    test('nombra las escrituras del asistente en es-MX', () {
      expect(toolTitleFor('create_flow'), 'Creó un flujo');
      expect(toolTitleFor('set_bot_paused'), 'Pausó o reanudó un bot');
      expect(toolTitleFor('update_step'), 'Actualizó un paso');
    });

    test('spawn_agent es "Delegó a un subagente"', () {
      expect(toolTitleFor('spawn_agent'), 'Delegó a un subagente');
    });

    test('una tool desconocida cae a «Usó <tool>»', () {
      expect(toolTitleFor('tool_del_futuro'), 'Usó tool_del_futuro');
    });

    // Migrados del mapa privado de trainer_change_card.dart: las tarjetas de
    // cambio del entrenador conservan sus títulos LITERALES (fijados también
    // por los tests de la tarjeta) al pasar al mapa central.
    test('nombra las escrituras del entrenador con sus títulos de tarjeta', () {
      expect(toolTitleFor('edit_prompt'), 'Prompt actualizado');
      expect(toolTitleFor('write_doc'), 'Documento creado');
      expect(toolTitleFor('edit_doc'), 'Documento actualizado');
      expect(toolTitleFor('delete_doc'), 'Documento borrado');
      expect(toolTitleFor('save_file'), 'Archivo guardado');
      expect(toolTitleFor('update_file_meta'), 'Archivo actualizado');
      expect(toolTitleFor('delete_file'), 'Archivo borrado');
    });

    test('nombra las lecturas del entrenador en es-MX', () {
      expect(toolTitleFor('get_template_overview'), 'Consultó la plantilla');
      expect(toolTitleFor('inspect_flow'), 'Inspeccionó un flujo');
      expect(toolTitleFor('list_labels'), 'Consultó las etiquetas');
      expect(toolTitleFor('validate_prompt'), 'Validó el prompt');
      expect(
        toolTitleFor('check_prompt_capabilities'),
        'Verificó las capacidades del prompt',
      );
      expect(toolTitleFor('read_bot_runs'), 'Revisó corridas de los bots');
      expect(toolTitleFor('read_prompt'), 'Leyó el prompt');
      expect(
        toolTitleFor('list_prompt_history'),
        'Consultó el historial del prompt',
      );
      expect(
        toolTitleFor('restore_prompt_version'),
        'Restauró una versión del prompt',
      );
      expect(toolTitleFor('list_docs'), 'Consultó los documentos');
      expect(toolTitleFor('read_doc'), 'Leyó un documento');
      expect(toolTitleFor('list_files'), 'Consultó los archivos');
      expect(
        toolTitleFor('list_recent_attachments'),
        'Consultó los adjuntos recientes',
      );
      expect(toolTitleFor('read_attachment'), 'Revisó un adjunto');
      expect(toolTitleFor('get_current_time'), 'Consultó la hora');
    });

    test('un nombre vacío cae a un genérico sin crudo del wire', () {
      expect(toolTitleFor(''), 'Usó una herramienta');
    });
  });

  group('toolIconFor', () {
    test('la familia de bots comparte ícono', () {
      expect(toolIconFor('list_bots'), toolIconFor('set_bot_paused'));
    });

    test('spawn_agent tiene su propio ícono, distinto del genérico', () {
      expect(toolIconFor('spawn_agent'), isNot(toolIconFor('tool_del_futuro')));
    });

    test('una tool desconocida cae al ícono genérico (bolt)', () {
      expect(toolIconFor('tool_del_futuro'), Icons.bolt);
    });

    // Migrados de trainer_change_card.dart: cada tarjeta conserva su ícono.
    test('las escrituras del entrenador conservan el ícono de su tarjeta', () {
      expect(toolIconFor('edit_prompt'), Icons.edit_note);
      expect(toolIconFor('write_doc'), Icons.note_add_outlined);
      expect(toolIconFor('edit_doc'), Icons.edit_document);
      expect(toolIconFor('delete_doc'), Icons.delete_outline);
      expect(toolIconFor('save_file'), Icons.attach_file);
      expect(toolIconFor('update_file_meta'), Icons.edit_attributes_outlined);
      expect(toolIconFor('delete_file'), Icons.delete_outline);
    });

    test('inspect_flow comparte el ícono de la familia de flujos', () {
      expect(toolIconFor('inspect_flow'), toolIconFor('get_flow'));
    });

    test('el historial del prompt usa el ícono de historial de su tarjeta', () {
      expect(toolIconFor('list_prompt_history'), Icons.history_outlined);
      expect(toolIconFor('restore_prompt_version'), Icons.history_outlined);
    });

    // Herramientas del bot en runtime (emulador del preview + hilo real): sus
    // lecturas y efectos entran al catálogo central para que el emulador deje
    // su mapa propio y todo lea igual.
    test('las herramientas del bot en runtime tienen su ícono en el catálogo '
        'central (ninguna cae al genérico)', () {
      expect(toolIconFor('read_document'), Icons.description_outlined);
      expect(toolIconFor('list_documents'), Icons.folder_open_outlined);
      expect(toolIconFor('read_labels'), Icons.label_outline);
      expect(toolIconFor('read_notes'), Icons.sticky_note_2_outlined);
      expect(toolIconFor('list_sendable_files'), Icons.attach_file);
      expect(toolIconFor('apply_label'), Icons.label_outline);
      expect(toolIconFor('save_note'), Icons.sticky_note_2_outlined);
      expect(toolIconFor('run_flow'), Icons.account_tree_outlined);
      expect(toolIconFor('react'), Icons.add_reaction_outlined);
      expect(toolIconFor('mark_read'), Icons.done_all);
      expect(toolIconFor('error'), Icons.error_outline);
      for (final t in <String>[
        'read_document',
        'apply_label',
        'run_flow',
        'mark_read',
        'error',
      ]) {
        expect(toolIconFor(t), isNot(Icons.bolt), reason: t);
      }
    });
  });
}
