import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/db/app_db.dart';
import 'core/network/connectivity_cubit.dart';
import 'core/network/connectivity_plus_monitor.dart';
import 'core/network/dio_client.dart';
import 'core/prefs/motion_settings_cubit.dart';
import 'core/router/app_router.dart';
import 'core/storage/device_id_provider.dart';
import 'core/storage/secure_kv_store.dart';
import 'features/ai_catalog/data/datasources/catalog_datasource.dart';
import 'features/ai_catalog/data/repositories/catalog_repository_impl.dart';
import 'features/org_ai_config/data/datasources/org_ai_config_datasource.dart';
import 'features/org_ai_config/data/repositories/org_ai_config_repository_impl.dart';
import 'features/org_customization/data/datasources/org_branding_datasource.dart';
import 'features/org_customization/data/repositories/org_branding_repository_impl.dart';
import 'features/auth/data/datasources/auth_datasource.dart';
import 'features/auth/data/interceptors/auth_interceptor.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/repositories/token_storage.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/bots/data/datasources/bot_session_datasource.dart';
import 'features/bots/data/datasources/bots_datasource.dart';
import 'features/bots/data/repositories/bot_session_repository_impl.dart';
import 'features/bots/data/repositories/bots_repository_impl.dart';
import 'features/conversations/data/datasources/conversations_dao.dart';
import 'features/conversations/data/datasources/conversations_datasource.dart';
import 'features/conversations/data/repositories/conversations_repository_impl.dart';
import 'features/flow_run/data/datasources/flow_run_datasource.dart';
import 'features/flow_run/data/repositories/flow_run_repository_impl.dart';
import 'features/flows/data/datasources/flows_datasource.dart';
import 'features/flows/data/repositories/flows_repository_impl.dart';
import 'features/labels/data/datasources/chat_labels_datasource.dart';
import 'features/labels/data/datasources/labels_datasource.dart';
import 'features/trainer/data/datasources/preview_datasource.dart';
import 'features/platform_agent/data/datasources/platform_agent_datasource.dart';
import 'features/platform_agent/data/datasources/platform_agent_events_datasource.dart';
import 'features/platform_agent/data/repositories/platform_agent_repositories_impl.dart';
import 'features/trainer/data/datasources/trainer_datasource.dart';
import 'features/monitor/data/datasources/monitor_activity_datasource.dart';
import 'features/monitor/data/datasources/monitor_catchup_datasource.dart';
import 'features/trainer/data/datasources/trainer_events_datasource.dart';
import 'features/trainer/data/datasources/workspace_datasource.dart';
import 'features/trainer/data/repositories/trainer_repositories_impl.dart';
import 'features/ai_ledger/data/ai_ledger_datasource.dart';
import 'features/ai_log/data/ai_log_datasource.dart';
import 'features/executions/data/execution_datasource.dart';
import 'features/notes/data/datasources/notes_datasource.dart';
import 'features/labels/data/repositories/chat_labels_repository_impl.dart';
import 'features/labels/data/repositories/labels_repository_impl.dart';
import 'features/notes/data/repositories/notes_repository_impl.dart';
import 'features/media/data/cache/caching_media_thumbnail_loader.dart';
import 'features/media/data/cache/dio_thumbnail_downloader.dart';
import 'features/media/data/cache/file_media_byte_store.dart';
import 'features/media/data/cache/file_media_page_store.dart';
import 'features/media/application/camera_capture_resolver.dart';
import 'features/media/application/device_gallery_resolver.dart';
import 'features/media/data/datasources/media_datasource.dart';
import 'features/media/data/repositories/caching_media_repository.dart';
import 'features/media/data/repositories/file_picker_media_file_picker.dart';
import 'features/media/data/repositories/media_repository_impl.dart';
import 'features/invitations/data/datasources/invitations_datasource.dart';
import 'features/invitations/data/repositories/invitations_repository_impl.dart';
import 'features/members/data/datasources/members_datasource.dart';
import 'features/members/data/repositories/members_repository_impl.dart';
import 'features/memberships/data/datasources/memberships_datasource.dart';
import 'features/memberships/data/repositories/memberships_repository_impl.dart';
import 'features/messages/data/datasources/messages_dao.dart';
import 'features/messages/data/datasources/messages_datasource.dart';
import 'features/messages/data/datasources/messages_events_datasource.dart';
import 'features/messages/data/cache/message_media_cache.dart';
import 'features/messages/data/datasources/outbox_dao.dart';
import 'features/messages/data/media/dio_media_opener.dart';
import 'features/messages/data/media/share_plus_media_sharer.dart';
import 'features/messages/application/audio_recorder_resolver.dart';
import 'features/messages/data/media/just_audio_engine.dart';
import 'features/messages/data/repositories/messages_repository_impl.dart';
import 'features/messages/data/sync/sync_coordinator.dart';
import 'features/notifications/application/push_display_bootstrap.dart';
import 'features/notifications/application/push_registration_coordinator.dart';
import 'features/notifications/application/push_token_provider_resolver.dart';
import 'features/notifications/data/datasources/notifications_datasource.dart';
import 'features/notifications/data/repositories/notifications_repository_impl.dart';
import 'features/profile/data/cache/profile_photo_cache.dart';
import 'features/profile/data/datasources/profile_datasource.dart';
import 'features/profile/data/repositories/profile_repository_impl.dart';
import 'features/templates/data/datasources/templates_datasource.dart';
import 'features/templates/data/repositories/templates_repository_impl.dart';
import 'features/triggers/data/datasources/triggers_datasource.dart';
import 'features/triggers/data/repositories/triggers_repository_impl.dart';
import 'features/quick_replies/data/datasources/quick_replies_catalog_datasource.dart';
import 'features/quick_replies/data/repositories/quick_replies_repository_impl.dart';
import 'features/wa_labels/data/datasources/wa_assoc_datasource.dart';
import 'features/wa_labels/data/datasources/wa_catalog_datasource.dart';
import 'features/wa_labels/data/datasources/wa_label_events_datasource.dart';
import 'features/wa_labels/data/datasources/wa_mapping_datasource.dart';
import 'features/wa_labels/data/repositories/wa_labels_repository_impl.dart';

/// Punto de entrada. Composición manual de dependencias — sin DI framework
/// hasta que un slice futuro lo justifique.
///
/// Dos instancias de Dio:
/// - `refreshDio`: SIN interceptor. Lo usa el AuthInterceptor para canjear
///   contra `/auth/refresh`. Romper el bucle 401→refresh→401 por
///   CONSTRUCCIÓN (instancia separada) es más fuerte que detectarlo por
///   URL — un cambio futuro de path no rompe la garantía.
/// - `mainDio`: con interceptor. Todos los endpoints de negocio salen por
///   aquí; Bearer + retry transparente del 401 son responsabilidad del
///   interceptor, no de los datasources.
///
/// `baseUrl` debe apuntar al `ataulfo-go` real. El default es producción
/// (`https://api.ataulfo.app`); en desarrollo se sobreescribe con
/// `--dart-define=AGENTIC_BASE_URL=http://10.0.2.2:8080` (localhost del
/// emulador Android) o con la IP LAN del backend.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Push FCM (S17) es Android-only y firebase_core no soporta Linux desktop:
  // el resolver inicializa Firebase y usa el provider real solo en Android (con
  // degradación a noop si Firebase falla), y noop directo en desktop/web.
  final pushTokens = await PushTokenProviderResolver(
    isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
  ).resolve();

  // Grabador de notas de voz: real (Opus vía `record`) solo en Android; Noop
  // en escritorio/web para que la app corra sin micrófono nativo. Singleton
  // de la app (el plugin nativo es de instancia única).
  final audioRecorder = AudioRecorderResolver(
    isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
  ).resolve();

  // Cámara del composer: real (vía `image_picker`) solo en Android; Noop en
  // escritorio/web para que el menú de adjuntar no ofrezca un destino muerto.
  final cameraCapture = CameraCaptureResolver(
    isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
  ).resolve();

  // Carrete del teléfono (previsualización de Galería del menú de adjuntar):
  // real (vía `photo_manager`) solo en Android; Noop en escritorio/web para
  // que el destino simplemente no aparezca.
  final deviceGallery = DeviceGalleryResolver(
    isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
  ).resolve();

  const baseUrl = String.fromEnvironment(
    'AGENTIC_BASE_URL',
    defaultValue: 'https://api.ataulfo.app',
  );

  final kv = FlutterSecureKvStore();
  final storage = TokenStorage(kv);
  final deviceIds = DeviceIdProvider(kv);

  // Preferencia de animaciones ANTES del primer frame: si el operador la
  // apagó, la app no debe arrancar animando y "calmarse" después.
  final motionSettings = await MotionSettingsCubit.load(kv);

  final refreshDio = DioClient.create(baseUrl: baseUrl);
  final refreshDs = DioAuthDatasource(refreshDio);

  final mainDio = DioClient.create(baseUrl: baseUrl);

  // Almacén local (drift/SQLite): única fuente de verdad offline del núcleo
  // conversacional. Se abre de forma perezosa; se purga al cerrar sesión
  // (abajo) para no dejar verdad local de una cuenta a la siguiente.
  final db = AppDb();

  // Señal de conectividad proactiva (online/offline): el cubit arranca el
  // monitoreo al lanzar la app y la UI/consumidores la leen globalmente. El
  // monitor también alimentará a los repos y al coordinador de sync.
  final connectivity = ConnectivityPlusMonitor();
  final connectivityCubit = ConnectivityCubit(connectivity);

  // `late` difiere la captura del bloc: la closure de onUnrecoverable se
  // construye antes que `authBloc`, pero solo se ejecuta en runtime.
  late final AuthBloc authBloc;

  // `late` difiere la captura del coordinator de push: el hook onBeforeLogout
  // se construye antes que el coordinator (que depende de repos posteriores),
  // pero sólo se ejecuta al cerrar sesión, cuando ya está cableado.
  late final PushRegistrationCoordinator pushCoordinator;

  mainDio.interceptors.add(
    AuthInterceptor(
      retryDio: mainDio,
      storage: storage,
      refreshDatasource: refreshDs,
      onUnrecoverable: () async {
        // El interceptor ya purgó el storage; re-disparamos el check
        // para que el bloc colapse a Unauthenticated y el redirect
        // navegue a /login. Una sola entrada al cambio de estado.
        authBloc.add(const AuthCheckRequested());
      },
    ),
  );

  final mainDs = DioAuthDatasource(mainDio);
  final authRepository = AuthRepositoryImpl(
    datasource: mainDs,
    storage: storage,
    // Desregistrar el device de push mientras el Bearer sigue vivo: el hook
    // corre antes de revocar y purgar la sesión, así el DELETE viaja
    // autenticado y el device no queda atado al usuario saliente.
    onBeforeLogout: () => pushCoordinator.unregisterForLogout(),
  );
  authBloc = AuthBloc(authRepository);

  final botsRepository = BotsRepositoryImpl(
    datasource: DioBotsDatasource(mainDio),
  );

  final botSessionRepository = BotSessionRepositoryImpl(
    datasource: DioBotSessionDatasource(mainDio),
  );

  final conversationsDao = ConversationsDao(db);
  final conversationsRepository = ConversationsRepositoryImpl(
    datasource: DioConversationsDatasource(mainDio),
    dao: conversationsDao,
  );

  final messagesDao = MessagesDao(db);
  final messagesDatasource = DioMessagesDatasource(mainDio);
  final outboxDao = OutboxDao(db);

  // Coordinador de sincronización: drena el outbox (escrituras encoladas) al
  // reconectar y reconcilia el resultado contra la DB local. Comparte el DAO y
  // el datasource del repositorio. Arranca rescatando operaciones huérfanas.
  final syncCoordinator = SyncCoordinator(
    db: db,
    outbox: outboxDao,
    messages: messagesDao,
    datasource: messagesDatasource,
    connectivity: connectivity,
  );

  // El envío va al outbox durable; `requestSync` dispara el drain para que salga
  // ya si hay red. La burbuja pendiente la observa el bloc vía watchPending.
  final messagesRepository = MessagesRepositoryImpl(
    datasource: messagesDatasource,
    events: DioMessagesEventsDatasource(mainDio),
    dao: messagesDao,
    outbox: outboxDao,
    requestSync: () => unawaited(syncCoordinator.drain()),
    // Al marcar leído, baja el badge de la fila en la bandeja (write-through
    // optimista): la bandeja observa la tabla conversations y re-emite ya.
    markConversationRead: conversationsDao.clearUnread,
    // Al vaciar el historial, la fila de la bandeja pierde preview y badge:
    // esos mensajes ya no existen.
    clearConversationProjection: conversationsDao.clearThreadProjection,
  );

  unawaited(syncCoordinator.start());

  final profileRepository = ProfileRepositoryImpl(
    datasource: DioProfileDatasource(mainDio),
  );

  // Caché de fotos de perfil (L1 memoria + L2 disco). La descarga usa un Dio
  // propio SIN interceptor de auth: la `photoUrl` es una URL pública efímera del
  // CDN de Meta, no un endpoint de negocio, así que no lleva Bearer.
  final profilePhotoCache = ProfilePhotoCache(
    profileRepo: profileRepository,
    download: _downloadBytes,
  );

  final templatesRepository = TemplatesRepositoryImpl(
    datasource: DioTemplatesDatasource(mainDio),
  );

  final flowsRepository = FlowsRepositoryImpl(
    datasource: DioFlowsDatasource(mainDio),
  );

  final flowRunRepository = FlowRunRepositoryImpl(
    DioFlowRunDatasource(mainDio),
  );

  final triggersRepository = TriggersRepositoryImpl(
    datasource: DioTriggersDatasource(mainDio),
  );

  // Etiquetas WhatsApp (S21): el repo agrega los cuatro datasources por
  // sub-recurso (catálogo/asociaciones/mapeo) más el realtime SSE, todos sobre
  // el mismo `mainDio` (Bearer + refresh transparente del interceptor).
  final waLabelsRepository = WaLabelsRepositoryImpl(
    catalog: DioWaCatalogDatasource(mainDio),
    assoc: DioWaAssocDatasource(mainDio),
    mapping: DioWaMappingDatasource(mainDio),
    events: DioWaLabelEventsDatasource(mainDio),
  );

  // Respuestas rápidas WhatsApp Business (S23): catálogo de solo lectura per-bot
  // que el composer del hilo ofrece en el selector ⚡.
  final quickRepliesRepository = QuickRepliesRepositoryImpl(
    catalog: DioQuickRepliesCatalogDatasource(mainDio),
  );

  // Labels internos (S10): el selector del mapeo WA↔interno los lista.
  final labelsRepository = LabelsRepositoryImpl(
    datasource: DioLabelsDatasource(mainDio),
  );

  // Aplicación de Labels internos por chat: el sheet de etiquetas del chat
  // (sección "Internas") los lee/aplica/quita. Mismo mainDio (Bearer).
  final chatLabelsRepository = ChatLabelsRepositoryImpl(
    datasource: DioChatLabelsDatasource(mainDio),
  );

  // Cuaderno de notas (S14): panel chat-scoped del hilo; mismo cuaderno que
  // escribe el agente IA con save_note.
  final notesRepository = NotesRepositoryImpl(
    datasource: DioNotesDatasource(mainDio),
  );

  // Observabilidad del bot (S12): el ai-log del chat real, ADMIN+.
  final aiLogRepository = AiLogRepositoryImpl(
    datasource: DioAiLogDatasource(mainDio),
  );
  // Bitácora de acciones con efecto (S30): SÓLO lo que el bot cambió, ADMIN+.
  final aiLedgerRepository = AiLedgerRepositoryImpl(
    datasource: DioAiLedgerDatasource(mainDio),
  );

  // Historial de ejecuciones de flujo del chat (S11), ADMIN+.
  final executionsRepository = ExecutionRepositoryImpl(
    datasource: DioExecutionsDatasource(mainDio),
  );

  // Agente entrenador + Workspace + Preview (S24): tres superficies del
  // mismo arco, page-scoped en sus rutas.
  final trainerRepository = TrainerRepositoryImpl(
    datasource: DioTrainerDatasource(mainDio),
  );
  final workspaceRepository = WorkspaceRepositoryImpl(
    datasource: DioWorkspaceDatasource(mainDio),
  );
  final previewRepository = PreviewRepositoryImpl(
    datasource: DioPreviewDatasource(mainDio),
  );

  // Asistente de plataforma (org-scoped): chat CRUD + turno síncrono y un
  // stream SSE de progreso. Vive como dock sobre el shell.
  final platformAgentRepository = PlatformAgentRepositoryImpl(
    datasource: DioPlatformAgentDatasource(mainDio),
  );
  final platformAgentEvents = PlatformAgentEventsImpl(
    datasource: DioPlatformAgentEventsDatasource(mainDio),
  );

  final membershipsRepository = MembershipsRepositoryImpl(
    datasource: DioMembershipsDatasource(mainDio),
  );

  final membersRepository = MembersRepositoryImpl(
    datasource: DioMembersDatasource(mainDio),
  );

  final invitationsRepository = InvitationsRepositoryImpl(
    datasource: DioInvitationsDatasource(mainDio),
  );

  final catalogRepository = CatalogRepositoryImpl(
    datasource: DioCatalogDatasource(mainDio),
  );

  final orgAiConfigRepository = OrgAiConfigRepositoryImpl(
    datasource: DioOrgAiConfigDatasource(mainDio),
  );

  final orgBrandingRepository = OrgBrandingRepositoryImpl(
    datasource: DioOrgBrandingDatasource(mainDio),
  );

  final notificationsRepository = NotificationsRepositoryImpl(
    datasource: DioNotificationsDatasource(mainDio),
  );

  pushCoordinator = PushRegistrationCoordinator(
    authBloc: authBloc,
    repository: notificationsRepository,
    deviceIds: deviceIds,
    tokens: pushTokens,
  );

  // Decoramos el repo con el cache de la primera página por familia type, vivo
  // a nivel de sesión (este singleton sobrevive a las entradas/salidas de la
  // galería, que es donde el bloc page-scoped re-listaba en cada visita). Se
  // purga en logout vía `onSignedOut` más abajo.
  //
  // Capa persistente + offline: persiste la primera página por `(orgId, type)`
  // en disco y la sirve (stale) si la red falla. El `orgId` sale de los claims
  // de auth y namespacea el disco — sin él (no autenticado) no se persiste.
  final mediaRepository = CachingMediaRepository(
    MediaRepositoryImpl(datasource: DioMediaDatasource(mainDio)),
    store: FileMediaPageStore(),
    orgId: () {
      final state = authBloc.state;
      return state is AuthAuthenticated ? state.identity.orgId : null;
    },
  );

  // Cache de bytes de miniatura por `ref` (inmutable, org-safe: el ref embebe
  // el tenant). A diferencia de la metadata, NO tiene TTL: una vez en disco,
  // la miniatura no se re-descarga al re-entrar a la galería ni depende de que
  // la firma de `previewUrl` siga viva. Singleton de sesión como el repo.
  final mediaThumbnailLoader = CachingMediaThumbnailLoader(
    store: FileMediaByteStore(),
    download: DioThumbnailDownloader().call,
  );

  // Cache de bytes de la media de los MENSAJES por `ref` (imagen/sticker del
  // hilo): se ve offline y sobrevive a la expiración de la firma. Namespace de
  // disco propio ('message_media'): la galería cachea MINIATURAS bajo el mismo
  // ref, contenido distinto de la imagen completa del mensaje.
  final messageMediaCache = MessageMediaCache(
    store: FileMediaByteStore(subdir: 'message_media'),
    download: _downloadBytes,
  );

  // El picker es un puerto sin estado; el adaptador concreto envuelve
  // `file_picker` y lee bytes cross-platform (no toca dart:io). file_picker
  // abre CUALQUIER tipo (audio/video/PDF/Office), no sólo imágenes.
  final mediaFilePicker = FilePickerMediaFilePicker();

  // Actividad del bot runtime: monitor por-chat + feed bot-scoped (mismo
  // datasource, dos interfaces).
  final monitorActivityDs = DioMonitorActivityDatasource(mainDio);
  // Catch-up del run en curso: hidrata el timeline al abrir un chat a mitad de
  // una corrida reusando los endpoints ai-log (no abre canal nuevo).
  final monitorCatchupDs = DioMonitorCatchupDatasource(mainDio);

  final router = AppRouter(
    authBloc: authBloc,
    authRepository: authRepository,
    botsRepository: botsRepository,
    botSessionRepository: botSessionRepository,
    conversationsRepository: conversationsRepository,
    messagesRepository: messagesRepository,
    profileRepository: profileRepository,
    templatesRepository: templatesRepository,
    flowsRepository: flowsRepository,
    flowRunRepository: flowRunRepository,
    triggersRepository: triggersRepository,
    waLabelsRepository: waLabelsRepository,
    quickRepliesRepository: quickRepliesRepository,
    labelsRepository: labelsRepository,
    chatLabelsRepository: chatLabelsRepository,
    notesRepository: notesRepository,
    aiLogRepository: aiLogRepository,
    aiLedgerRepository: aiLedgerRepository,
    executionsRepository: executionsRepository,
    trainerRepository: trainerRepository,
    trainerEvents: DioTrainerEventsDatasource(mainDio),
    // Un solo datasource sirve el monitor por-chat (ADMIN+) y el feed bot-scoped
    // (operador): implementa ambas interfaces.
    monitorActivity: monitorActivityDs,
    monitorBotActivity: monitorActivityDs,
    monitorCatchup: monitorCatchupDs,
    workspaceRepository: workspaceRepository,
    previewRepository: previewRepository,
    platformAgentRepository: platformAgentRepository,
    platformAgentEvents: platformAgentEvents,
    membershipsRepository: membershipsRepository,
    membersRepository: membersRepository,
    invitationsRepository: invitationsRepository,
    catalogRepository: catalogRepository,
    orgAiConfigRepository: orgAiConfigRepository,
    orgBrandingRepository: orgBrandingRepository,
    notificationsRepository: notificationsRepository,
    mediaRepository: mediaRepository,
    mediaFilePicker: mediaFilePicker,
    cameraCapture: cameraCapture,
    deviceGallery: deviceGallery,
    mediaThumbnailLoader: mediaThumbnailLoader,
    // Media del hilo: descarga-y-abre con app externa (URL firmada pública,
    // Dio propio sin Authorization) y player de audio nuevo por visita.
    mediaOpener: DioMediaOpener(),
    mediaSharer: SharePlusMediaSharer(),
    audioEngineFactory: JustAudioEngine.new,
    audioRecorder: audioRecorder,
  );

  // Visualización + navegación de push; no-op si el push real no está activo
  // (desktop/web, o Android sin Firebase). Va DESPUÉS del router porque el
  // tap de una notificación navega con él.
  await startPushDisplay(
    pushTokens,
    authBloc: authBloc,
    navigate: (location) => router.router.go(location),
  );

  // Dispara el check inicial: lee storage, si hay tokens valida con
  // /auth/me, emite Authenticated o Unauthenticated. El Splash se queda
  // hasta que el primer estado no-Initial llegue.
  authBloc.add(const AuthCheckRequested());
  unawaited(pushCoordinator.start());

  // Fire-and-forget: el device_id queda persistido en cuanto pueda. Los
  // consumidores post-login lo leen desde el mismo provider.
  unawaited(deviceIds.getOrCreate());

  runApp(
    AtaulfoApp(
      router: router,
      authBloc: authBloc,
      connectivityCubit: connectivityCubit,
      motionSettings: motionSettings,
      profilePhotoCache: profilePhotoCache,
      messageMediaCache: messageMediaCache,
      // Al cerrar sesión, purga las cachés de sesión (media, respuestas rápidas
      // y fotos de perfil) para no servir el catálogo de una cuenta a la
      // siguiente sin reiniciar la app.
      onSignedOut: () {
        mediaRepository.invalidate();
        quickRepliesRepository.invalidate();
        unawaited(profilePhotoCache.invalidate());
        // Limpia la memoria de la caché de media de mensajes (los bytes en disco
        // son inmutables y org-safe — el ref embebe el tenant —, se conservan).
        messageMediaCache.invalidate();
        // Fencea cualquier reconciliación del outbox en vuelo ANTES de purgar:
        // un envío que confirme tras el borrado no debe repoblar la DB.
        syncCoordinator.reset();
        // Borra la verdad local (drift): ninguna fila de la cuenta anterior
        // debe persistir. Fire-and-forget: el router redirige a /login y nada
        // vuelve a leer la DB durante el borrado.
        unawaited(db.clearAllData());
      },
      // Al cambiar de organización activa (mismo usuario, otra org): purga las
      // cachés de sesión y la verdad local RECONSTRUIBLE para no mostrar datos
      // de la org anterior en la nueva; el outbox (escrituras sin sincronizar)
      // se CONSERVA (no se pierde una escritura offline por cambiar de org).
      onOrgChanged: () {
        mediaRepository.invalidate();
        quickRepliesRepository.invalidate();
        unawaited(profilePhotoCache.invalidate());
        messageMediaCache.invalidate();
        // Fencea cualquier reconciliación del outbox en vuelo antes de purgar.
        syncCoordinator.reset();
        unawaited(db.clearReadData());
      },
    ),
  );
}

/// Descarga bytes de una URL (fotos de perfil, media de mensajes) con timeouts
/// explícitos: una URL del CDN que se cuelga no debe dejar la descarga (ni el
/// slot de dedup de la caché) colgada para siempre. `null` si falla.
Future<Uint8List?> _downloadBytes(String url) async {
  try {
    final res = await Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    ).get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    final data = res.data;
    return data == null ? null : Uint8List.fromList(data);
  } catch (_) {
    return null;
  }
}
