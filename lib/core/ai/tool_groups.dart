import 'package:flutter/material.dart';

/// Grupo de capacidad del agente IA (permisos de herramientas).
///
/// Los `wire` son el contrato con el backend: la deny-list `disabled_tool_groups`
/// viaja como lista de estos ids. DEBEN coincidir EXACTAMENTE con
/// `aitools.ValidGroups()` del backend (lowercase español); un test guard lo
/// verifica para que el drift cross-repo salga en CI, no en runtime.
///
/// La única herramienta núcleo (cerrar turno) NO es un grupo: el agente siempre
/// la tiene. Por eso no aparece aquí. La mensajería (responder por texto) SÍ es
/// un grupo gateable.
///
/// Esto es un catálogo de PRESENTACIÓN (icono + label + descripción); la config
/// del dominio guarda solo los ids (`List<String>`), igual que las etiquetas de
/// silencio — tolerante a que el backend agregue un grupo futuro.
enum ToolGroup {
  mensajeria(
    'mensajeria',
    'Mensajería',
    'Responder por texto a la persona. Si la desactivas, el bot no enviará '
        'mensajes escritos (solo podrá usar sus otras capacidades).',
    Icons.chat_bubble_outline,
  ),
  acuse(
    'acuse',
    'Acuse y reacción',
    'Marcar como leído el mensaje y reaccionar con un emoji.',
    Icons.done_all,
  ),
  etiquetas(
    'etiquetas',
    'Etiquetas',
    'Leer el catálogo de etiquetas y etiquetar la conversación.',
    Icons.label_outline,
  ),
  notas(
    'notas',
    'Notas',
    'Leer y guardar notas del cliente (memoria de largo plazo).',
    Icons.sticky_note_2_outlined,
  ),
  flujos(
    'flujos',
    'Flujos',
    'Descubrir, inspeccionar y ejecutar flujos de automatización.',
    Icons.account_tree_outlined,
  ),
  documentos(
    'documentos',
    'Documentos',
    'Consultar el workspace de documentos del negocio (precios, políticas…).',
    Icons.description_outlined,
  ),
  archivos(
    'archivos',
    'Archivos',
    'Listar y enviar archivos del catálogo de medios.',
    Icons.attach_file,
  ),
  alertas(
    'alertas',
    'Alertas al operador',
    'Avisar a una persona del equipo cuando haga falta.',
    Icons.notifications_active_outlined,
  ),
  hora('hora', 'Hora', 'Consultar la hora actual.', Icons.schedule),
  percepcion(
    'percepcion',
    'Percepción',
    'Describir imágenes y leer el texto de documentos adjuntos.',
    Icons.visibility_outlined,
  );

  const ToolGroup(this.wire, this.label, this.description, this.icon);

  /// Id de wire del grupo (clave de la deny-list `disabled_tool_groups`).
  final String wire;

  /// Nombre legible para la UI.
  final String label;

  /// Descripción de lo que habilita el grupo.
  final String description;

  /// Ícono representativo del grupo.
  final IconData icon;

  /// Busca un grupo por su id de wire. `null` si es desconocido (un grupo que
  /// un backend futuro podría agregar): el caller decide tratarlo como huérfano
  /// preservable, NO descartarlo en silencio.
  static ToolGroup? fromWireOrNull(String raw) {
    for (final g in values) {
      if (g.wire == raw) return g;
    }
    return null;
  }
}
