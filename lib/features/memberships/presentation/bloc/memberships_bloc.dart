import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/membership.dart';
import '../../domain/failures/memberships_failure.dart';
import '../../domain/repositories/memberships_repository.dart';

/// Bloc del listado de memberships. Se monta page-scoped: la página de
/// `/memberships` dispara `LoadRequested` al construirse, sin Refresh
/// (regla de 3: pull-to-refresh entra cuando un caso de uso real lo pida).
class MembershipsBloc extends Bloc<MembershipsEvent, MembershipsState> {
  MembershipsBloc(this._repo) : super(const MembershipsInitial()) {
    on<MembershipsLoadRequested>(_onLoad);
  }

  final MembershipsRepository _repo;

  Future<void> _onLoad(
    MembershipsLoadRequested event,
    Emitter<MembershipsState> emit,
  ) async {
    emit(const MembershipsLoading());
    try {
      final items = await _repo.list();
      emit(MembershipsLoaded(items: items));
    } on MembershipsFailure catch (f) {
      emit(MembershipsFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class MembershipsEvent {
  const MembershipsEvent();
}

class MembershipsLoadRequested extends MembershipsEvent {
  const MembershipsLoadRequested();

  @override
  bool operator ==(Object other) => other is MembershipsLoadRequested;
  @override
  int get hashCode => (MembershipsLoadRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class MembershipsState {
  const MembershipsState();
}

class MembershipsInitial extends MembershipsState {
  const MembershipsInitial();
  @override
  bool operator ==(Object other) => other is MembershipsInitial;
  @override
  int get hashCode => (MembershipsInitial).hashCode;
}

class MembershipsLoading extends MembershipsState {
  const MembershipsLoading();
  @override
  bool operator ==(Object other) => other is MembershipsLoading;
  @override
  int get hashCode => (MembershipsLoading).hashCode;
}

class MembershipsLoaded extends MembershipsState {
  const MembershipsLoaded({required this.items});

  final List<Membership> items;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MembershipsLoaded) return false;
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items);
}

class MembershipsFailed extends MembershipsState {
  const MembershipsFailed(this.failure);

  final MembershipsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is MembershipsFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
