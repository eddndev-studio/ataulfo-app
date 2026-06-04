import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/invitation.dart';
import '../../domain/failures/invitations_failure.dart';
import '../../domain/repositories/invitations_repository.dart';

/// Bloc del historial de invitaciones de la org activa. Page-scoped: la página
/// dispara `LoadRequested` al construirse y la recarga tras una mutación
/// (emitir/cancelar) exitosa o cuando una cancelación falla por 404/410.
class InvitationsBloc extends Bloc<InvitationsEvent, InvitationsState> {
  InvitationsBloc(this._repo) : super(const InvitationsInitial()) {
    on<InvitationsLoadRequested>(_onLoad);
  }

  final InvitationsRepository _repo;

  Future<void> _onLoad(
    InvitationsLoadRequested event,
    Emitter<InvitationsState> emit,
  ) async {
    emit(const InvitationsLoading());
    try {
      final items = await _repo.list();
      emit(InvitationsLoaded(items: items));
    } on InvitationsFailure catch (f) {
      emit(InvitationsFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class InvitationsEvent {
  const InvitationsEvent();
}

class InvitationsLoadRequested extends InvitationsEvent {
  const InvitationsLoadRequested();

  @override
  bool operator ==(Object other) => other is InvitationsLoadRequested;
  @override
  int get hashCode => (InvitationsLoadRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class InvitationsState {
  const InvitationsState();
}

class InvitationsInitial extends InvitationsState {
  const InvitationsInitial();
  @override
  bool operator ==(Object other) => other is InvitationsInitial;
  @override
  int get hashCode => (InvitationsInitial).hashCode;
}

class InvitationsLoading extends InvitationsState {
  const InvitationsLoading();
  @override
  bool operator ==(Object other) => other is InvitationsLoading;
  @override
  int get hashCode => (InvitationsLoading).hashCode;
}

class InvitationsLoaded extends InvitationsState {
  const InvitationsLoaded({required this.items});

  final List<Invitation> items;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! InvitationsLoaded) return false;
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items);
}

class InvitationsFailed extends InvitationsState {
  const InvitationsFailed(this.failure);

  final InvitationsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is InvitationsFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}
