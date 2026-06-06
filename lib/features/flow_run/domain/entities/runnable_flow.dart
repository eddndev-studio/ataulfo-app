/// Una fila del selector de "correr flujo" en el chat (S11 `GET
/// /sessions/:botId/flows`): un flujo ACTIVO del bot que el operador puede
/// arrancar a demanda. Sólo `id` + `name` — lo mínimo para listar y elegir.
class RunnableFlow {
  const RunnableFlow({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is RunnableFlow && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
