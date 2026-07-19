import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/resource_item.dart';
import '../../domain/repositories/resources_repository.dart';

sealed class AssistantResourcesState {
  const AssistantResourcesState();
}

final class AssistantResourcesLoading extends AssistantResourcesState {
  const AssistantResourcesLoading();
}

final class AssistantResourcesFailed extends AssistantResourcesState {
  const AssistantResourcesFailed(this.message);

  final String message;
}

final class AssistantResourcesLoaded extends AssistantResourcesState {
  const AssistantResourcesLoaded({
    required this.library,
    required this.effectiveIds,
    required this.scope,
    required this.revision,
    this.saving = false,
    this.needsReload = false,
    this.notice,
  });

  final List<ResourceItem> library;
  final Set<String> effectiveIds;
  final AssistantResourceScope scope;
  final int revision;
  final bool saving;

  /// true sólo cuando un cambio de ALL→SELECTED fue aceptado pero el refetch
  /// falló: bajo ALL no sabemos cuáles filas eran bindings explícitos, así que
  /// no debemos mostrar interruptores potencialmente falsos.
  final bool needsReload;
  final String? notice;

  AssistantResourcesLoaded copyWith({
    List<ResourceItem>? library,
    Set<String>? effectiveIds,
    AssistantResourceScope? scope,
    int? revision,
    bool? saving,
    bool? needsReload,
    String? notice,
    bool clearNotice = false,
  }) => AssistantResourcesLoaded(
    library: library ?? this.library,
    effectiveIds: effectiveIds ?? this.effectiveIds,
    scope: scope ?? this.scope,
    revision: revision ?? this.revision,
    saving: saving ?? this.saving,
    needsReload: needsReload ?? this.needsReload,
    notice: clearNotice ? null : notice ?? this.notice,
  );
}

class AssistantResourcesCubit extends Cubit<AssistantResourcesState> {
  AssistantResourcesCubit({
    required ResourcesRepository repository,
    required String assistantId,
  }) : _repository = repository,
       _assistantId = assistantId,
       super(const AssistantResourcesLoading());

  final ResourcesRepository _repository;
  final String _assistantId;

  Future<void> load() async {
    emit(const AssistantResourcesLoading());
    try {
      final results =
          await Future.wait<ResourceSnapshot>(<Future<ResourceSnapshot>>[
            _repository.listOrganization(),
            _repository.listForAssistant(_assistantId),
          ]);
      final organization = results[0];
      final assistant = results[1];
      emit(
        AssistantResourcesLoaded(
          library: organization.resources,
          effectiveIds: assistant.resources.map((item) => item.id).toSet(),
          scope: assistant.scope ?? AssistantResourceScope.all,
          revision: assistant.revision,
        ),
      );
    } on ResourcesFailure catch (failure) {
      emit(AssistantResourcesFailed(failure.message));
    } on Object {
      emit(const AssistantResourcesFailed('No pudimos cargar los recursos.'));
    }
  }

  Future<void> setScope(AssistantResourceScope scope) async {
    final current = state;
    if (current is! AssistantResourcesLoaded ||
        current.saving ||
        current.scope == scope) {
      return;
    }
    emit(current.copyWith(saving: true, clearNotice: true));
    try {
      await _repository.setScope(_assistantId, scope);
      final losesBindingVisibility =
          current.scope == AssistantResourceScope.all &&
          scope == AssistantResourceScope.selected;
      final fallbackIds = scope == AssistantResourceScope.all
          ? current.library.map((item) => item.id).toSet()
          : losesBindingVisibility
          ? current.library
                .where((item) => item.sharedByDefault)
                .map((item) => item.id)
                .toSet()
          : current.effectiveIds;
      await _reloadKeeping(
        current.copyWith(
          scope: scope,
          effectiveIds: fallbackIds,
          needsReload: losesBindingVisibility,
        ),
      );
    } on ResourcesFailure catch (failure) {
      emit(current.copyWith(saving: false, notice: failure.message));
    }
  }

  Future<void> setResource(
    ResourceItem resource, {
    required bool selected,
  }) async {
    final current = state;
    if (current is! AssistantResourcesLoaded ||
        current.saving ||
        current.needsReload) {
      return;
    }
    emit(current.copyWith(saving: true, clearNotice: true));
    try {
      if (selected) {
        await _repository.attach(_assistantId, resource.id);
      } else {
        await _repository.detach(_assistantId, resource.id);
      }
      final effectiveIds = Set<String>.of(current.effectiveIds);
      if (selected) {
        effectiveIds.add(resource.id);
      } else {
        effectiveIds.remove(resource.id);
      }
      await _reloadKeeping(current.copyWith(effectiveIds: effectiveIds));
    } on ResourcesFailure catch (failure) {
      emit(current.copyWith(saving: false, notice: failure.message));
    }
  }

  Future<void> _reloadKeeping(AssistantResourcesLoaded fallback) async {
    try {
      final results =
          await Future.wait<ResourceSnapshot>(<Future<ResourceSnapshot>>[
            _repository.listOrganization(),
            _repository.listForAssistant(_assistantId),
          ]);
      emit(
        AssistantResourcesLoaded(
          library: results[0].resources,
          effectiveIds: results[1].resources.map((item) => item.id).toSet(),
          scope: results[1].scope ?? fallback.scope,
          revision: results[1].revision,
          needsReload: false,
        ),
      );
    } on Object {
      emit(
        fallback.copyWith(
          saving: false,
          notice: 'El cambio se guardó, pero falta recargar la Biblioteca.',
        ),
      );
    }
  }
}
