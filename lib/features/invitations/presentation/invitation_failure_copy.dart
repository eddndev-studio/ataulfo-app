import '../domain/failures/invitations_failure.dart';

/// Copy canónico de los fallos de invitaciones para sheets y páginas.
String invitationFailureMessage(InvitationsFailure failure) =>
    switch (failure) {
      InvitationsDuplicateFailure() =>
        'Ya hay una invitación pendiente para ese correo; '
            'cancélala para reinvitar.',
      InvitationsValidationFailure() =>
        'Revisa el correo y vuelve a intentarlo.',
      InvitationsGoneFailure() => 'Esa invitación ya no se puede cancelar.',
      InvitationsNotFoundFailure() => 'Esa invitación ya no existe.',
      InvitationsForbiddenFailure() =>
        'No tienes permiso para gestionar invitaciones.',
      InvitationsNetworkFailure() || InvitationsTimeoutFailure() =>
        'Sin conexión. Revisa tu red e inténtalo de nuevo.',
      InvitationsServerFailure() =>
        'No pudimos confirmar la operación; revisa el historial.',
      UnknownInvitationsFailure() => 'Algo salió mal. Inténtalo de nuevo.',
    };
