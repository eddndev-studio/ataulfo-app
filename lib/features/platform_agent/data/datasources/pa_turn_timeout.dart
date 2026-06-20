/// Presupuesto de recepción del POST síncrono que corre un turno del motor
/// del asistente de plataforma.
///
/// El `receiveTimeout` global de Dio está dimensionado para CRUD; un turno
/// del motor puede tardar mucho más (varias llamadas al proveedor + tools
/// encadenadas). El cliente debe esperar MÁS que el presupuesto del motor en
/// el server (AI_RUN_TIMEOUT) y que el proxy: así el que corta es siempre el
/// server y el cliente recibe el 502 estructurado en vez de rendirse antes
/// con un timeout local mientras el turno sigue corriendo.
const Duration paTurnReceiveTimeout = Duration(seconds: 180);
