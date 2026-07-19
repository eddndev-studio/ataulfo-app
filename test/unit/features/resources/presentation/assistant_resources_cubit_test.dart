import 'package:ataulfo/features/resources/domain/entities/resource_item.dart';
import 'package:ataulfo/features/resources/domain/repositories/resources_repository.dart';
import 'package:ataulfo/features/resources/presentation/bloc/assistant_resources_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

const _document = ResourceItem(
  id: 'r-doc',
  sourceId: 'd-1',
  kind: ResourceKind.knowledgeDocument,
  name: 'Política de cambios',
  active: true,
  sharedByDefault: false,
  indexable: true,
  sendable: false,
  version: 2,
);

const _catalog = ResourceItem(
  id: 'r-file',
  sourceId: 'f-1',
  kind: ResourceKind.file,
  name: 'Catálogo.pdf',
  active: true,
  sharedByDefault: false,
  indexable: false,
  sendable: true,
  version: 1,
);

class _FakeResourcesRepository implements ResourcesRepository {
  _FakeResourcesRepository({this.scope = AssistantResourceScope.all});

  List<ResourceItem> organization = const <ResourceItem>[_document, _catalog];
  List<ResourceItem> effective = const <ResourceItem>[_document];
  AssistantResourceScope scope;
  int revision = 7;
  String? attached;
  String? detached;
  AssistantResourceScope? changedScope;
  ResourcesFailure? mutationFailure;
  bool failReloadAfterMutation = false;
  bool _mutated = false;

  @override
  Future<ResourceSnapshot> listOrganization() async =>
      ResourceSnapshot(revision: revision, resources: organization);

  @override
  Future<ResourceSnapshot> listForAssistant(String assistantId) async {
    if (_mutated && failReloadAfterMutation) {
      throw const ResourcesFailure('No pudimos confirmar el cambio.');
    }
    return ResourceSnapshot(
      revision: revision,
      resources: effective,
      scope: scope,
    );
  }

  @override
  Future<void> setScope(String assistantId, AssistantResourceScope next) async {
    if (mutationFailure case final failure?) throw failure;
    changedScope = next;
    scope = next;
    _mutated = true;
    revision++;
  }

  @override
  Future<void> attach(String assistantId, String resourceId) async {
    if (mutationFailure case final failure?) throw failure;
    attached = resourceId;
    final resource = organization.firstWhere((item) => item.id == resourceId);
    effective = <ResourceItem>[
      ...effective.where((item) => item.id != resourceId),
      resource,
    ];
    _mutated = true;
    revision++;
  }

  @override
  Future<void> detach(String assistantId, String resourceId) async {
    if (mutationFailure case final failure?) throw failure;
    detached = resourceId;
    effective = effective.where((item) => item.id != resourceId).toList();
    _mutated = true;
    revision++;
  }
}

void main() {
  test(
    'load combina catálogo organizacional, política y recursos efectivos',
    () async {
      final repository = _FakeResourcesRepository();
      final cubit = AssistantResourcesCubit(
        repository: repository,
        assistantId: 'assistant-1',
      );
      addTearDown(cubit.close);

      await cubit.load();

      final state = cubit.state as AssistantResourcesLoaded;
      expect(state.library.map((item) => item.id), <String>['r-doc', 'r-file']);
      expect(state.effectiveIds, <String>{'r-doc'});
      expect(state.scope, AssistantResourceScope.all);
      expect(state.revision, 7);
      expect(state.saving, isFalse);
    },
  );

  test(
    'cambiar a SELECTED conserva la decisión si falla sólo la recarga',
    () async {
      final repository = _FakeResourcesRepository()
        ..failReloadAfterMutation = true;
      final cubit = AssistantResourcesCubit(
        repository: repository,
        assistantId: 'assistant-1',
      );
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.setScope(AssistantResourceScope.selected);

      final state = cubit.state as AssistantResourcesLoaded;
      expect(repository.changedScope, AssistantResourceScope.selected);
      expect(state.scope, AssistantResourceScope.selected);
      expect(state.saving, isFalse);
      expect(state.needsReload, isTrue);
      expect(state.effectiveIds, isEmpty);
      expect(
        state.notice,
        'El cambio se guardó, pero falta recargar la Biblioteca.',
      );
    },
  );

  test('attach refleja el cambio confirmado aunque falle el refetch', () async {
    final repository = _FakeResourcesRepository(
      scope: AssistantResourceScope.selected,
    )..failReloadAfterMutation = true;
    final cubit = AssistantResourcesCubit(
      repository: repository,
      assistantId: 'assistant-1',
    );
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.setResource(_catalog, selected: true);

    final state = cubit.state as AssistantResourcesLoaded;
    expect(repository.attached, 'r-file');
    expect(state.effectiveIds, contains('r-file'));
    expect(state.needsReload, isFalse);
    expect(
      state.notice,
      'El cambio se guardó, pero falta recargar la Biblioteca.',
    );
  });

  test(
    'rechazo inherited conserva snapshot y explica por qué no se quitó',
    () async {
      final repository =
          _FakeResourcesRepository(scope: AssistantResourceScope.selected)
            ..mutationFailure = const ResourcesFailure(
              'Incluido por la organización.',
              inherited: true,
            );
      final cubit = AssistantResourcesCubit(
        repository: repository,
        assistantId: 'assistant-1',
      );
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.setResource(_document, selected: false);

      final state = cubit.state as AssistantResourcesLoaded;
      expect(state.effectiveIds, <String>{'r-doc'});
      expect(state.notice, 'Incluido por la organización.');
      expect(state.saving, isFalse);
    },
  );
}
