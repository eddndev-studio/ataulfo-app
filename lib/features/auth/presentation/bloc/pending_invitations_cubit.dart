import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/pending_invitation.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// Cubit de las invitaciones pendientes del operador (la cara del RECEPTOR).
/// Lista `GET /auth/invitations/pending` y acepta con `accept-pending`.
///
/// Es best-effort de fricción baja: la lista se pinta en "Tus organizaciones"
/// como una sección extra, y CUALQUIER fallo al cargar la deja vacía (oculta),
/// nunca un error a la cara. El stream sólo lleva la lista durable y el id que
/// se está uniendo (spinner de la fila); el desenlace de `join` —que dispara
/// SnackBar, navegación y recarga de memberships— vuelve como resultado del
/// Future para que la PÁGINA orqueste esos efectos cross-bloc, no el cubit.
class PendingInvitationsCubit extends Cubit<PendingInvitationsState> {
  PendingInvitationsCubit(this._repo)
    : super(const PendingInvitationsLoading());

  final AuthRepository _repo;

  Future<void> load() async {
    try {
      final items = await _repo.pendingInvitations();
      if (isClosed) return;
      emit(PendingInvitationsReady(items: items));
    } on AuthFailure {
      // Best-effort: sin invitaciones a la vista la sección se oculta. No se
      // filtra el fallo (el backend devuelve [] si el correo no está verificado,
      // y una caída de red no debe ensuciar la pantalla de organizaciones).
      if (isClosed) return;
      emit(const PendingInvitationsReady(items: <PendingInvitation>[]));
    }
  }

  /// Acepta la invitación [id]. Marca la fila en curso (spinner) en el stream y
  /// devuelve el desenlace para que la página muestre el aviso y recargue. En
  /// éxito (y en "ya miembro"/"expirada") recarga la lista de pendientes para
  /// que la fila desaparezca. Cada `emit` tras un await va tras la guarda
  /// `isClosed`: si la ruta se cerró a media petición, no se toca un cubit
  /// cerrado (StateError) y el desenlace vuelve igual —la página lo ignora por
  /// su propia guarda de `mounted`—.
  Future<PendingJoinResult> join(String id) async {
    final current = state;
    final items = current is PendingInvitationsReady
        ? current.items
        : const <PendingInvitation>[];
    emit(PendingInvitationsReady(items: items, joiningId: id));
    try {
      final accepted = await _repo.acceptPendingInvitation(id);
      if (isClosed) return PendingJoinOk(orgName: accepted.orgName);
      await load();
      return PendingJoinOk(orgName: accepted.orgName);
    } on EmailNotVerifiedFailure {
      if (isClosed) return const PendingJoinNeedsVerification();
      emit(PendingInvitationsReady(items: items));
      return const PendingJoinNeedsVerification();
    } on AlreadyMemberFailure {
      // Ya eres miembro: la fila está stale, recarga para que desaparezca.
      if (isClosed) return const PendingJoinAlreadyMember();
      await load();
      return const PendingJoinAlreadyMember();
    } on ExpiredTokenFailure {
      // Consumida o expirada: ya no es accionable; recarga para retirarla.
      if (isClosed) return const PendingJoinGone();
      await load();
      return const PendingJoinGone();
    } on AuthFailure {
      if (isClosed) return const PendingJoinFailed();
      emit(PendingInvitationsReady(items: items));
      return const PendingJoinFailed();
    }
  }
}

// Estados de la lista -------------------------------------------------------

sealed class PendingInvitationsState {
  const PendingInvitationsState();
}

/// Carga inicial en vuelo: la sección se oculta hasta que haya lista.
class PendingInvitationsLoading extends PendingInvitationsState {
  const PendingInvitationsLoading();

  @override
  bool operator ==(Object other) => other is PendingInvitationsLoading;

  @override
  int get hashCode => (PendingInvitationsLoading).hashCode;
}

/// Lista resuelta. Vacía ⇒ la sección se oculta. [joiningId] marca la fila en
/// curso de aceptación (spinner en su botón) mientras el resto sigue tappable.
class PendingInvitationsReady extends PendingInvitationsState {
  const PendingInvitationsReady({required this.items, this.joiningId});

  final List<PendingInvitation> items;
  final String? joiningId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PendingInvitationsReady) return false;
    if (other.joiningId != joiningId) return false;
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(items), joiningId);
}

// Desenlace de un intento de unión ------------------------------------------

sealed class PendingJoinResult {
  const PendingJoinResult();
}

/// Unión exitosa: la membership existe (aún no activa). Lleva el nombre para
/// confirmar el ingreso.
class PendingJoinOk extends PendingJoinResult {
  const PendingJoinOk({required this.orgName});

  final String orgName;
}

/// 403: el correo del caller no está verificado. La UI pide verificarlo.
class PendingJoinNeedsVerification extends PendingJoinResult {
  const PendingJoinNeedsVerification();
}

/// 409: ya eres miembro de esa org. Informativo (no un fallo a reintentar).
class PendingJoinAlreadyMember extends PendingJoinResult {
  const PendingJoinAlreadyMember();
}

/// 410: la invitación se consumió o expiró — ya no está disponible.
class PendingJoinGone extends PendingJoinResult {
  const PendingJoinGone();
}

/// Cualquier otro fallo (red, 404, genérico): reintento simple.
class PendingJoinFailed extends PendingJoinResult {
  const PendingJoinFailed();
}
