import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/member.dart';
import '../../domain/failures/members_failure.dart';
import '../../domain/repositories/members_repository.dart';

/// Bloc del listado de miembros de la org activa. Se monta page-scoped: la
/// página dispara `LoadRequested` al construirse, sin Refresh (regla de 3:
/// pull-to-refresh entra cuando un caso de uso real lo pida).
class MembersBloc extends Bloc<MembersEvent, MembersState> {
  MembersBloc(this._repo) : super(const MembersInitial()) {
    on<MembersLoadRequested>(_onLoad);
  }

  final MembersRepository _repo;

  Future<void> _onLoad(
    MembersLoadRequested event,
    Emitter<MembersState> emit,
  ) async {
    emit(const MembersLoading());
    try {
      final items = await _repo.list();
      emit(MembersLoaded(items: items));
    } on MembersFailure catch (f) {
      emit(MembersFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class MembersEvent {
  const MembersEvent();
}

class MembersLoadRequested extends MembersEvent {
  const MembersLoadRequested();

  @override
  bool operator ==(Object other) => other is MembersLoadRequested;
  @override
  int get hashCode => (MembersLoadRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class MembersState {
  const MembersState();
}

class MembersInitial extends MembersState {
  const MembersInitial();
  @override
  bool operator ==(Object other) => other is MembersInitial;
  @override
  int get hashCode => (MembersInitial).hashCode;
}

class MembersLoading extends MembersState {
  const MembersLoading();
  @override
  bool operator ==(Object other) => other is MembersLoading;
  @override
  int get hashCode => (MembersLoading).hashCode;
}

class MembersLoaded extends MembersState {
  const MembersLoaded({required this.items});

  final List<Member> items;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MembersLoaded) return false;
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items);
}

class MembersFailed extends MembersState {
  const MembersFailed(this.failure);

  final MembersFailure failure;

  @override
  bool operator ==(Object other) =>
      other is MembersFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
