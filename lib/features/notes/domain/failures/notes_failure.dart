/// Fallos tipados del cuaderno de notas (S14). El datasource mapea status
/// HTTP → failure; los blocs los muestran como copy accionable.
sealed class NotesFailure implements Exception {
  const NotesFailure();
}

/// 409 — la `version` enviada ya no es la persistida (otro editor —humano o
/// IA— ganó el CAS). El cliente debe recargar y reintentar.
class NotesConflictFailure extends NotesFailure {
  const NotesConflictFailure();
}

/// 422 — contenido vacío/sobre límite o tags inválidas (reglas S14).
class NotesValidationFailure extends NotesFailure {
  const NotesValidationFailure();
}

/// 404 — la nota no existe en la org (o no es visible para el rol).
class NotesNotFoundFailure extends NotesFailure {
  const NotesNotFoundFailure();
}

/// 403 — el rol no alcanza (WORKER sin membership resoluble).
class NotesForbiddenFailure extends NotesFailure {
  const NotesForbiddenFailure();
}

class NotesNetworkFailure extends NotesFailure {
  const NotesNetworkFailure();
}

class NotesTimeoutFailure extends NotesFailure {
  const NotesTimeoutFailure();
}

class NotesServerFailure extends NotesFailure {
  const NotesServerFailure();
}

class NotesUnknownFailure extends NotesFailure {
  const NotesUnknownFailure();
}
