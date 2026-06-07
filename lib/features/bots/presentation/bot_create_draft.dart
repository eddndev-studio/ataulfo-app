import '../../templates/domain/entities/template.dart';

/// Borrador en curso del wizard de creación de bot: la plantilla elegida y el
/// texto ya tecleado. Es estado de UI (no dominio): existe sólo para sobrevivir
/// a que el usuario cierre el modal por accidente (tap fuera, swipe, back) sin
/// perder su progreso.
class BotCreateDraft {
  const BotCreateDraft({this.template, this.name = '', this.identifier = ''});

  final Template? template;
  final String name;
  final String identifier;

  /// Un borrador sin plantilla ni texto no vale la pena guardar: equivale a no
  /// tener borrador.
  bool get isEmpty => template == null && name.isEmpty && identifier.isEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BotCreateDraft &&
        other.template == template &&
        other.name == name &&
        other.identifier == identifier;
  }

  @override
  int get hashCode => Object.hash(template, name, identifier);
}

/// Caché en memoria de un único borrador del wizard de creación de bot. Vive
/// colgado del subárbol del shell acotado por la org activa: persiste mientras
/// el usuario sigue en la app dentro de su org, y se descarta al cambiar de org
/// (un borrador con la plantilla de la org A no debe aparecer en la org B).
///
/// No persiste a disco: el objetivo es no perder el progreso al cerrar el modal
/// por accidente, no sobrevivir a un reinicio de la app.
class BotCreateDraftStore {
  BotCreateDraft? _draft;

  /// El borrador vigente, o `null` si no hay ninguno.
  BotCreateDraft? get current => _draft;

  /// Guarda [draft] como borrador vigente. Un borrador vacío limpia en vez de
  /// guardar: vaciar el formulario equivale a descartar.
  void save(BotCreateDraft draft) {
    _draft = draft.isEmpty ? null : draft;
  }

  /// Descarta el borrador vigente (creación exitosa o descarte explícito).
  void clear() {
    _draft = null;
  }
}
