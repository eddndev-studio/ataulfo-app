import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entitlement.dart';
import '../../domain/failures/billing_failure.dart';
import '../../domain/repositories/billing_repository.dart';

/// Bloc del entitlement de la org activa. Se monta page-scoped en las
/// superficies que gatean UI por plan (p.ej. el editor de AIConfig filtra el
/// picker de cerebro a `eligibleProviders`). Sin Refresh event — un retry
/// desde Failed reusa LoadRequested.
///
/// El entitlement es AUXILIAR: los consumidores degradan con gracia cuando
/// no está cargado (Failed/Loading ⇒ mismo comportamiento que sin filtro; el
/// backend valida de todas formas). Ninguna pantalla debe bloquearse por él.
class EntitlementBloc extends Bloc<EntitlementEvent, EntitlementState> {
  EntitlementBloc(this._repo) : super(const EntitlementInitial()) {
    on<EntitlementLoadRequested>(_onLoad);
  }

  final BillingRepository _repo;

  Future<void> _onLoad(
    EntitlementLoadRequested event,
    Emitter<EntitlementState> emit,
  ) async {
    emit(const EntitlementLoading());
    try {
      final entitlement = await _repo.fetch();
      emit(EntitlementLoaded(entitlement: entitlement));
    } on BillingFailure catch (f) {
      emit(EntitlementFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class EntitlementEvent {
  const EntitlementEvent();
}

class EntitlementLoadRequested extends EntitlementEvent {
  const EntitlementLoadRequested();

  @override
  bool operator ==(Object other) => other is EntitlementLoadRequested;
  @override
  int get hashCode => (EntitlementLoadRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class EntitlementState {
  const EntitlementState();
}

class EntitlementInitial extends EntitlementState {
  const EntitlementInitial();
  @override
  bool operator ==(Object other) => other is EntitlementInitial;
  @override
  int get hashCode => (EntitlementInitial).hashCode;
}

class EntitlementLoading extends EntitlementState {
  const EntitlementLoading();
  @override
  bool operator ==(Object other) => other is EntitlementLoading;
  @override
  int get hashCode => (EntitlementLoading).hashCode;
}

class EntitlementLoaded extends EntitlementState {
  const EntitlementLoaded({required this.entitlement});

  final Entitlement entitlement;

  @override
  bool operator ==(Object other) =>
      other is EntitlementLoaded && other.entitlement == entitlement;

  @override
  int get hashCode => entitlement.hashCode;
}

class EntitlementFailed extends EntitlementState {
  const EntitlementFailed(this.failure);

  final BillingFailure failure;

  @override
  bool operator ==(Object other) =>
      other is EntitlementFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
