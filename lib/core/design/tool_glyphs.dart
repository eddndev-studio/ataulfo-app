import 'package:flutter/material.dart';

/// Mapa central tool→(ícono, título es-MX) para las trazas del asistente, el
/// entrenador y el hilo real. Antes cada superficie tenía su propio switch
/// divergente; esto unifica el idioma para que un mismo tool se lea igual en
/// toda la app.
///
/// Los títulos son etiquetas de paso, operador-facing y en pasado —el registro
/// que usa una traza estilo Claude ("Consultó los bots", "Creó un flujo")—.
/// JAMÁS se muestra el nombre crudo del wire salvo en el fallback explícito
/// «Usó `<tool>`», que es la degradación honesta ante un tool que este build aún
/// no conoce.

/// Título humano del tool. Vacío ⇒ genérico sin crudo; desconocido ⇒
/// «Usó `<tool>`».
String toolTitleFor(String tool) {
  switch (tool) {
    // Lecturas.
    case 'list_bots':
      return 'Consultó los bots';
    case 'get_bot':
      return 'Consultó un bot';
    case 'get_bot_variables':
      return 'Consultó variables de un bot';
    case 'list_templates':
      return 'Consultó las plantillas';
    case 'get_template':
      return 'Consultó una plantilla';
    case 'list_flows':
      return 'Consultó los flujos';
    case 'get_flow':
      return 'Consultó un flujo';
    case 'list_steps':
      return 'Consultó los pasos';
    case 'list_triggers':
      return 'Consultó los disparadores';
    case 'list_media':
      return 'Consultó la galería';
    case 'list_platform_docs':
      return 'Consultó la documentación';
    case 'read_prompt_section':
      return 'Leyó una sección del prompt';
    case 'view_file':
      return 'Leyó un archivo';
    case 'explain_bot_run':
      return 'Revisó una corrida de bot';
    case 'check_flow_integrity':
      return 'Verificó un flujo';
    case 'check_template_integrity':
      return 'Verificó una plantilla';
    // Bots.
    case 'set_bot_paused':
      return 'Pausó o reanudó un bot';
    case 'set_bot_ai_disabled':
      return 'Activó o desactivó la IA de un bot';
    case 'set_bot_tool_groups':
      return 'Ajustó los permisos de un bot';
    case 'set_bot_variables':
      return 'Actualizó variables de un bot';
    // Variables.
    case 'add_variable':
      return 'Creó una variable';
    case 'update_variable':
      return 'Actualizó una variable';
    case 'remove_variable':
      return 'Eliminó una variable';
    // Plantillas.
    case 'create_template':
      return 'Creó una plantilla';
    case 'update_template':
      return 'Actualizó una plantilla';
    case 'delete_template':
      return 'Eliminó una plantilla';
    case 'clone_template':
      return 'Duplicó una plantilla';
    case 'patch_template_ai':
      return 'Ajustó la IA de una plantilla';
    // Flujos.
    case 'create_flow':
      return 'Creó un flujo';
    case 'update_flow':
      return 'Actualizó un flujo';
    case 'delete_flow':
      return 'Eliminó un flujo';
    case 'clone_flow':
      return 'Duplicó un flujo';
    // Pasos.
    case 'create_step':
      return 'Agregó un paso';
    case 'update_step':
      return 'Actualizó un paso';
    case 'delete_step':
      return 'Eliminó un paso';
    case 'reorder_steps':
      return 'Reordenó los pasos';
    // Disparadores.
    case 'create_trigger':
      return 'Creó un disparador';
    case 'update_trigger':
      return 'Actualizó un disparador';
    case 'delete_trigger':
      return 'Eliminó un disparador';
    // Etiquetas.
    case 'create_label':
      return 'Creó una etiqueta';
    case 'update_label':
      return 'Actualizó una etiqueta';
    case 'delete_label':
      return 'Eliminó una etiqueta';
    // Documentos y archivos.
    case 'deliver_document':
      return 'Entregó un documento';
    case 'publish_sendable_file':
      return 'Publicó un archivo enviable';
    case 'set_document_branding':
      return 'Configuró la marca de documentos';
    case 'sandbox_exec':
      return 'Ejecutó código';
    case 'sandbox_write_file':
      return 'Escribió un archivo';
    case 'sandbox_add_media':
      return 'Agregó un archivo a la galería';
    // Memoria.
    case 'remember':
      return 'Guardó una memoria';
    case 'recall_memory':
      return 'Recordó del historial';
    // Entrenador — lecturas del catálogo (trainertools).
    case 'get_template_overview':
      return 'Consultó la plantilla';
    case 'inspect_flow':
      return 'Inspeccionó un flujo';
    case 'list_labels':
      return 'Consultó las etiquetas';
    case 'read_bot_runs':
      return 'Revisó corridas de los bots';
    case 'list_recent_attachments':
      return 'Consultó los adjuntos recientes';
    case 'read_attachment':
      return 'Revisó un adjunto';
    case 'get_current_time':
      return 'Consultó la hora';
    // Entrenador — prompt.
    case 'read_prompt':
      return 'Leyó el prompt';
    case 'validate_prompt':
      return 'Validó el prompt';
    case 'check_prompt_capabilities':
      return 'Verificó las capacidades del prompt';
    case 'list_prompt_history':
      return 'Consultó el historial del prompt';
    case 'restore_prompt_version':
      return 'Restauró una versión del prompt';
    // Entrenador — escrituras del workspace. Títulos LITERALES de las tarjetas
    // de cambio (trainer_change_card): la tarjeta y el nodo de la traza deben
    // leer idéntico.
    case 'edit_prompt':
      return 'Prompt actualizado';
    case 'list_docs':
      return 'Consultó los documentos';
    case 'read_doc':
      return 'Leyó un documento';
    case 'write_doc':
      return 'Documento creado';
    case 'edit_doc':
      return 'Documento actualizado';
    case 'delete_doc':
      return 'Documento borrado';
    case 'list_files':
      return 'Consultó los archivos';
    case 'save_file':
      return 'Archivo guardado';
    case 'update_file_meta':
      return 'Archivo actualizado';
    case 'delete_file':
      return 'Archivo borrado';
    // Delegación.
    case 'spawn_agent':
      return 'Delegó a un subagente';
    case 'done':
      return 'Terminó';
    case '':
      return 'Usó una herramienta';
    default:
      return 'Usó $tool';
  }
}

/// Ícono del tool. Desconocido ⇒ [Icons.bolt] (el genérico de acción).
IconData toolIconFor(String tool) {
  switch (tool) {
    // Bots.
    case 'list_bots':
    case 'get_bot':
    case 'get_bot_variables':
    case 'set_bot_paused':
    case 'set_bot_ai_disabled':
    case 'set_bot_tool_groups':
    case 'set_bot_variables':
      return Icons.smart_toy_outlined;
    // Variables.
    case 'add_variable':
    case 'update_variable':
    case 'remove_variable':
      return Icons.data_object;
    // Plantillas.
    case 'list_templates':
    case 'get_template':
    case 'create_template':
    case 'update_template':
    case 'delete_template':
    case 'clone_template':
    case 'patch_template_ai':
    case 'check_template_integrity':
      return Icons.dashboard_customize_outlined;
    // Flujos, pasos y disparadores.
    case 'inspect_flow':
    case 'list_flows':
    case 'get_flow':
    case 'create_flow':
    case 'update_flow':
    case 'delete_flow':
    case 'clone_flow':
    case 'check_flow_integrity':
    case 'list_steps':
    case 'create_step':
    case 'update_step':
    case 'delete_step':
    case 'reorder_steps':
    case 'list_triggers':
    case 'create_trigger':
    case 'update_trigger':
    case 'delete_trigger':
      return Icons.account_tree_outlined;
    // Etiquetas.
    case 'create_label':
    case 'update_label':
    case 'delete_label':
      return Icons.label_outline;
    // Documentos, galería y sandbox de archivos.
    case 'list_media':
    case 'deliver_document':
    case 'publish_sendable_file':
    case 'set_document_branding':
    case 'sandbox_add_media':
      return Icons.perm_media_outlined;
    case 'view_file':
    case 'sandbox_write_file':
      return Icons.description_outlined;
    case 'sandbox_exec':
      return Icons.terminal;
    // Documentación y prompt.
    case 'read_prompt_section':
    case 'list_platform_docs':
      return Icons.menu_book_outlined;
    // Diagnóstico.
    case 'explain_bot_run':
      return Icons.troubleshoot;
    // Memoria.
    case 'remember':
    case 'recall_memory':
      return Icons.bookmark_outline;
    // Entrenador — lecturas y prompt.
    case 'get_template_overview':
      return Icons.dashboard_customize_outlined;
    case 'list_labels':
      return Icons.label_outline;
    case 'read_bot_runs':
      return Icons.troubleshoot;
    case 'list_recent_attachments':
    case 'read_attachment':
      return Icons.attach_file;
    case 'get_current_time':
      return Icons.schedule_outlined;
    case 'read_prompt':
    case 'validate_prompt':
    case 'check_prompt_capabilities':
      return Icons.menu_book_outlined;
    case 'list_prompt_history':
    case 'restore_prompt_version':
      return Icons.history_outlined;
    // Entrenador — escrituras del workspace. Íconos LITERALES de las tarjetas
    // de cambio (trainer_change_card).
    case 'edit_prompt':
      return Icons.edit_note;
    case 'list_docs':
    case 'read_doc':
      return Icons.description_outlined;
    case 'write_doc':
      return Icons.note_add_outlined;
    case 'edit_doc':
      return Icons.edit_document;
    case 'delete_doc':
    case 'delete_file':
      return Icons.delete_outline;
    case 'list_files':
      return Icons.folder_open_outlined;
    case 'save_file':
      return Icons.attach_file;
    case 'update_file_meta':
      return Icons.edit_attributes_outlined;
    // Delegación.
    case 'spawn_agent':
      return Icons.hub_outlined;
    case 'done':
      return Icons.check_circle_outline;
    // Herramientas del bot en RUNTIME (emulador del preview + hilo real): sus
    // lecturas y efectos entran al catálogo central para que el emulador deje
    // su mapa propio y un mismo tool se lea igual en toda la app.
    case 'read_document':
      return Icons.description_outlined;
    case 'list_documents':
      return Icons.folder_open_outlined;
    case 'read_labels':
    case 'apply_label':
      return Icons.label_outline;
    case 'read_notes':
    case 'save_note':
      return Icons.sticky_note_2_outlined;
    case 'list_sendable_files':
      return Icons.attach_file;
    case 'run_flow':
      return Icons.account_tree_outlined;
    case 'react':
      return Icons.add_reaction_outlined;
    case 'mark_read':
      return Icons.done_all;
    // Efecto sintético de un flush fallido del emulador (no un tool real): su
    // ícono de peligro delata que algo no se grabó.
    case 'error':
      return Icons.error_outline;
    default:
      return Icons.bolt;
  }
}
