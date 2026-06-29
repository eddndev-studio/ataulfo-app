# ataulfo v0.17.0 — Novedades

_Comparado con v0.16.3._

Tres grandes saltos: los chats de agentes se vuelven un puesto de mando real, la interfaz se pule, y el núcleo conversacional empieza a funcionar sin conexión.

## Chats de agentes de primer nivel

- **Monitor en vivo del bot** — En el hilo (ADMIN+), ves en tiempo real qué hace el bot: burbuja de "escribiendo", herramienta en uso y razonamiento, con reconexión automática y recuperación de la corrida en curso.
- **Estado y alertas a la vista** — Píldora "Pensando" / "Falló la última corrida" en el encabezado, banner de alerta descartable, y señal "Atención" en la bandeja para los chats que fallaron.
- **Control por conversación** — Pausar o reanudar el bot en un chat específico, sin afectar a los demás.
- **Observabilidad** — Ver el razonamiento desde un mensaje del bot, y una bitácora de solo lo que el bot cambió (envíos, etiquetas, flujos, notas).
- **Entrenador y Asistente más sólidos** — Texto con formato (Markdown), reintentar/detener/borrador por conversación, razonamiento colapsable, historial del prompt con restaurar, selector de hilos, inspección de flujos, y renombrar/eliminar hilos.

## Mejoras de interfaz

- **Barra del hilo ordenada** — Las acciones se agrupan en un menú "Más acciones" (⋮) en vez de apiñarse.
- **Etiquetas de WhatsApp en la bandeja** — Filtro por etiqueta y cápsulas de color por chat; el refresco las mantiene al día.
- **Bandeja compacta** — Lista densa estilo mensajería (filas a sangre, divisores delgados).
- **Hojas inferiores mejores** — Respetan la barra de estado y se cierran arrastrando desde una manija; la hoja de etiquetas abre ya poblada desde la bandeja.

## Funcionamiento sin conexión (offline-first)

- **Lectura sin red** — La bandeja y los hilos abren al instante con lo último visto y se leen sin conexión; imágenes, stickers y fotos de perfil quedan en caché.
- **Escritura sin red** — Enviar mensajes, marcar leído y reaccionar funcionan offline: se aplican de inmediato, se encolan y se sincronizan solos al reconectar (sin duplicar ni perder estado). Si algo falla, puedes reintentar o descartar.
- **Avisos claros** — Banner global "Sin conexión", y arrancar sin red ya no te saca al login (muestra una vista de reconexión que entra sola al volver la red).

### Limitaciones conocidas

- En frío sin red entras a una vista de reconexión, aún no directo a la bandeja.
- Audio, video y documentos offline se muestran como tarjeta de tipo (con red, completos).
- Los datos locales aún no se limpian solos y pueden crecer con el tiempo.

## Resumen

Ves y controlas en vivo lo que hace cada bot, la interfaz queda más ordenada y cercana a una app de mensajería, y la app abre al instante, se usa sin red y se sincroniza sola al reconectar.
