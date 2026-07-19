import '../entities/resource_item.dart';

class ResourcesFailure implements Exception {
  const ResourcesFailure(this.message, {this.inherited = false});

  final String message;
  final bool inherited;

  @override
  String toString() => message;
}

abstract interface class ResourcesRepository {
  Future<ResourceSnapshot> listOrganization();

  Future<ResourceSnapshot> listForAssistant(String assistantId);

  Future<void> setScope(String assistantId, AssistantResourceScope scope);

  Future<void> attach(String assistantId, String resourceId);

  Future<void> detach(String assistantId, String resourceId);
}
