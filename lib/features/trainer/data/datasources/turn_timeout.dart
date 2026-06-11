/// Presupuesto de recepción de los POST síncronos que corren un turno del
/// motor IA (hilo del entrenador y preview sandbox).
///
/// El `receiveTimeout` global de Dio está dimensionado para CRUD; un turno
/// del motor puede legítimamente tardar mucho más (varias llamadas al
/// proveedor encadenadas). El cliente debe esperar MÁS que el presupuesto
/// del motor en el server (AI_RUN_TIMEOUT) y que el proxy: así el que corta
/// es siempre el server y el cliente recibe el 502 estructurado en vez de
/// rendirse antes con un timeout local mientras el turno sigue corriendo.
const Duration turnReceiveTimeout = Duration(seconds: 180);
