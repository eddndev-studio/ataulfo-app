import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../memberships/domain/repositories/memberships_repository.dart';
import '../../domain/entities/org_branding.dart';
import '../../domain/failures/org_branding_failure.dart';
import '../../domain/repositories/org_branding_repository.dart';

/// Estado agregado del módulo de personalización: el nombre de la org activa
/// (de memberships, best-effort) + la marca de documentos (autoridad). Las
/// mutaciones recargan la marca fresca del backend — la vista nunca adivina
/// el resultado de un PUT/DELETE.
class OrgCustomizationCubit extends Cubit<OrgCustomizationState> {
  OrgCustomizationCubit({
    required OrgBrandingRepository branding,
    required MembershipsRepository memberships,
    required String activeOrgId,
  }) : _branding = branding,
       _memberships = memberships,
       _activeOrgId = activeOrgId,
       super(const OrgCustomizationLoading());

  final OrgBrandingRepository _branding;
  final MembershipsRepository _memberships;
  final String _activeOrgId;

  Future<void> load() async {
    emit(const OrgCustomizationLoading());
    try {
      final branding = await _branding.get();
      emit(
        OrgCustomizationReady(orgName: await _activeName(), branding: branding),
      );
    } on OrgBrandingFailure catch (f) {
      emit(OrgCustomizationError(f));
    }
  }

  /// Nombre de la org activa vía la lista de memberships. Best-effort: si la
  /// lista falla, el módulo sigue siendo usable (el logo es lo central) y el
  /// nombre queda vacío.
  Future<String> _activeName() async {
    try {
      final items = await _memberships.list();
      for (final m in items) {
        if (m.orgId == _activeOrgId) return m.orgName;
      }
      return '';
    } on Exception {
      return '';
    }
  }

  Future<void> setLogo(String mediaRef) =>
      _mutate((repo) => repo.setLogo(mediaRef));

  Future<void> reset() => _mutate((repo) => repo.reset());

  Future<void> _mutate(
    Future<void> Function(OrgBrandingRepository repo) op,
  ) async {
    final current = state;
    if (current is! OrgCustomizationReady || current.saving) return;
    emit(current.copyWith(saving: true));
    try {
      await op(_branding);
      emit(
        OrgCustomizationReady(
          orgName: current.orgName,
          branding: await _branding.get(),
        ),
      );
    } on OrgBrandingFailure catch (f) {
      emit(current.copyWith(saving: false, mutationFailure: f));
    }
  }
}

// States ----------------------------------------------------------------

sealed class OrgCustomizationState {
  const OrgCustomizationState();
}

class OrgCustomizationLoading extends OrgCustomizationState {
  const OrgCustomizationLoading();

  @override
  bool operator ==(Object other) => other is OrgCustomizationLoading;

  @override
  int get hashCode => (OrgCustomizationLoading).hashCode;
}

class OrgCustomizationError extends OrgCustomizationState {
  const OrgCustomizationError(this.failure);

  final OrgBrandingFailure failure;

  @override
  bool operator ==(Object other) =>
      other is OrgCustomizationError && other.failure == failure;

  @override
  int get hashCode => Object.hash(OrgCustomizationError, failure);
}

class OrgCustomizationReady extends OrgCustomizationState {
  const OrgCustomizationReady({
    required this.orgName,
    required this.branding,
    this.saving = false,
    this.mutationFailure,
  });

  final String orgName;
  final OrgBranding branding;

  /// Hay una mutación en vuelo: las acciones se deshabilitan.
  final bool saving;

  /// Falla de la ÚLTIMA mutación (el estado previo se conserva); la página
  /// la anuncia una vez vía listener.
  final OrgBrandingFailure? mutationFailure;

  OrgCustomizationReady copyWith({
    bool? saving,
    OrgBrandingFailure? mutationFailure,
  }) {
    return OrgCustomizationReady(
      orgName: orgName,
      branding: branding,
      saving: saving ?? this.saving,
      mutationFailure: mutationFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrgCustomizationReady &&
        other.orgName == orgName &&
        other.branding == branding &&
        other.saving == saving &&
        other.mutationFailure == mutationFailure;
  }

  @override
  int get hashCode => Object.hash(orgName, branding, saving, mutationFailure);
}
