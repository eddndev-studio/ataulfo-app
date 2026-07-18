import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/media/media_byte_sink.dart';
import '../../../media/domain/repositories/media_file_picker.dart';
import '../../domain/entities/pa_attachment.dart';
import '../../domain/entities/pa_conversation.dart';
import '../../domain/entities/pa_message.dart';
import '../../domain/entities/pa_models.dart';
import '../../domain/entities/pa_progress.dart';
import '../../domain/failures/pa_failure.dart';
import '../../domain/repositories/platform_agent_repository.dart';

/// Página de historial que el chat carga por turno. El POST síncrono ya
/// devuelve el assistant final, pero el hilo completo (tool results) vive en
/// el server: tras cada turno se RECARGA.
const int _pageLimit = 50;
const String _newTitle = '';

sealed class PaChatEvent {
  const PaChatEvent();
}

final class PaChatStarted extends PaChatEvent {
  const PaChatStarted();
}

/// Siembra un handoff contextual en el composer sin enviarlo. Puede llegar
/// mientras PaChatStarted aún carga; el bloc lo aplica al hilo que resulte
/// activo cuando termine.
final class PaChatDraftSeeded extends PaChatEvent {
  const PaChatDraftSeeded(this.text);

  final String text;
}

final class PaChatMessageSent extends PaChatEvent {
  const PaChatMessageSent(this.content);

  final String content;

  @override
  bool operator ==(Object other) =>
      other is PaChatMessageSent && other.content == content;

  @override
  int get hashCode => content.hashCode;
}

final class PaChatNewConversationRequested extends PaChatEvent {
  const PaChatNewConversationRequested();
}

/// El operador pide cargar el tramo de historial anterior (mensajes viejos).
final class PaChatLoadMore extends PaChatEvent {
  const PaChatLoadMore();
}

/// Renombrar un hilo del historial.
final class PaChatConversationRenamed extends PaChatEvent {
  const PaChatConversationRenamed(this.id, this.title);

  final String id;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is PaChatConversationRenamed &&
      other.id == id &&
      other.title == title;

  @override
  int get hashCode => Object.hash(id, title);
}

/// Eliminar un hilo del historial.
final class PaChatConversationDeleted extends PaChatEvent {
  const PaChatConversationDeleted(this.id);

  final String id;

  @override
  bool operator ==(Object other) =>
      other is PaChatConversationDeleted && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

final class PaChatConversationSelected extends PaChatEvent {
  const PaChatConversationSelected(this.id);

  final String id;

  @override
  bool operator ==(Object other) =>
      other is PaChatConversationSelected && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// El operador quiere adjuntar un archivo al turno: abre el picker y, si elige,
/// lo sube al hilo (la ref queda PENDIENTE hasta el send).
final class PaChatAttachRequested extends PaChatEvent {
  const PaChatAttachRequested();
}

/// Quita un adjunto pendiente (por ref) antes de enviar.
final class PaChatAttachmentRemoved extends PaChatEvent {
  const PaChatAttachmentRemoved(this.ref);

  final String ref;

  @override
  bool operator ==(Object other) =>
      other is PaChatAttachmentRemoved && other.ref == ref;

  @override
  int get hashCode => ref.hashCode;
}

/// El operador elige el modelo para los próximos turnos. id vacío ⇒ vuelve al
/// default de la plataforma (el turno viaja sin model).
final class PaChatModelSelected extends PaChatEvent {
  const PaChatModelSelected(this.modelId);

  final String modelId;

  @override
  bool operator ==(Object other) =>
      other is PaChatModelSelected && other.modelId == modelId;

  @override
  int get hashCode => modelId.hashCode;
}

/// El operador detiene el turno en vuelo: aborta el POST y revierte el optimista.
final class PaChatTurnCancelRequested extends PaChatEvent {
  const PaChatTurnCancelRequested();
}

/// Empieza a grabar una nota de voz (bloquea el envío de texto: una a la vez).
final class PaChatVoiceStarted extends PaChatEvent {
  const PaChatVoiceStarted();
}

/// Descarta la grabación en curso sin enviarla.
final class PaChatVoiceCancelled extends PaChatEvent {
  const PaChatVoiceCancelled();
}

/// Envía la nota de voz grabada: corre el turno vía sendAudio (mismo manejo
/// que un mensaje de texto: sending/typing/SSE/cancel/fallos).
final class PaChatVoiceSent extends PaChatEvent {
  const PaChatVoiceSent(this.bytes, {this.filename = 'voice.ogg'});

  final Uint8List bytes;
  final String filename;
}

/// El composer cambió: persiste el borrador del hilo activo (sin re-emitir por
/// tecla; el borrador se siembra al cambiar de hilo).
final class PaChatDraftChanged extends PaChatEvent {
  const PaChatDraftChanged(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is PaChatDraftChanged && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// Interno: un frame de progreso del SSE del turno en vuelo. Alimenta el
/// indicador en vivo; no toca el hilo de mensajes.
final class PaChatProgressReceived extends PaChatEvent {
  const PaChatProgressReceived(this.event);

  final PaProgressEvent event;
}

sealed class PaChatState {
  const PaChatState();
}

final class PaChatLoading extends PaChatState {
  const PaChatLoading();

  @override
  bool operator ==(Object other) => other is PaChatLoading;

  @override
  int get hashCode => (PaChatLoading).hashCode;
}

final class PaChatFailed extends PaChatState {
  const PaChatFailed(this.failure);

  final PaFailure failure;

  @override
  bool operator ==(Object other) =>
      other is PaChatFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

final class PaChatLoaded extends PaChatState {
  const PaChatLoaded({
    required this.conversations,
    required this.activeConversation,
    required this.messages,
    required this.sending,
    this.sendFailure,
    this.liveEvents = const <PaProgressEvent>[],
    this.livePartial = false,
    this.liveStopped = false,
    this.models = const <PaModelOption>[],
    this.defaultModelId = '',
    this.selectedModelId = '',
    this.nextCursor = '',
    this.loadingMore = false,
    this.lastAttemptedContent = '',
    this.draft = '',
    this.pendingAttachments = const <PaAttachment>[],
    this.pendingThumbnails = const <String, Uint8List>{},
    this.attaching = false,
    this.recordingVoice = false,
  });

  /// Hilos del operador, DESC por updatedAt (para el selector de historial).
  final List<PaConversation> conversations;

  /// Hilo abierto.
  final PaConversation activeConversation;

  /// Mensajes del hilo activo en orden cronológico ASC (listo para render).
  final List<PaMessage> messages;

  /// true mientras el turno viaja (composer bloqueado + indicador en vivo).
  final bool sending;

  /// Fallo del ÚLTIMO turno (el hilo sigue usable); null si no hubo.
  final PaFailure? sendFailure;

  /// Eventos de progreso del SSE acumulados del turno en vuelo, en orden de
  /// llegada: alimentan la traza viva (thinking/tool → nodos; terminales
  /// aportan la causa del fallo). Se conservan tras el cierre del POST hasta
  /// que la recarga triunfa (swap a la gramática persistida) — si la recarga
  /// falla, son el único registro del proceso y quedan marcados parciales.
  final List<PaProgressEvent> liveEvents;

  /// La recarga post-cierre falló o llegó rezagada: la traza viva se conserva
  /// pintada con la marca «(traza parcial)» en lugar de descartarse.
  final bool livePartial;

  /// El operador detuvo el turno: la traza viva queda colapsada al copy
  /// honesto («Detenido aquí — el servidor pudo continuar») hasta el próximo
  /// turno o cambio de hilo.
  final bool liveStopped;

  /// Allowlist de modelos (best-effort: vacía oculta el selector — backend sin
  /// la ruta o fallo de carga).
  final List<PaModelOption> models;

  /// Modelo default de la plataforma (informativo, para marcarlo en el menú).
  final String defaultModelId;

  /// Elección vigente del operador; '' = default (el turno viaja sin model).
  final String selectedModelId;

  /// Cursor de la página anterior (más vieja); '' = no hay más historial.
  final String nextCursor;

  /// true mientras se cargan mensajes viejos (load-more en vuelo).
  final bool loadingMore;

  /// Texto del último turno enviado, conservado al fallar para que "Reintentar"
  /// lo re-despache y el composer lo recupere. '' cuando no hay nada que reintentar.
  final String lastAttemptedContent;

  /// Borrador del composer del hilo ACTIVO; se siembra al cambiar de hilo o al
  /// cancelar (la persistencia por-hilo vive en el bloc, en memoria).
  final String draft;

  /// Adjuntos YA subidos esperando el próximo send (chips en el composer).
  final List<PaAttachment> pendingAttachments;

  /// Bytes locales de los adjuntos-imagen pendientes, por ref: alimentan la
  /// miniatura del chip sin pedirla a la red. Solo viven para los pendientes
  /// (se descartan al enviar o quitar); NUNCA se persisten en drafts.
  final Map<String, Uint8List> pendingThumbnails;

  /// true mientras un adjunto sube (el clip muestra spinner).
  final bool attaching;

  /// true mientras se graba una nota de voz: reemplaza el composer por la barra
  /// de grabación y bloquea el envío de texto (una cosa a la vez).
  final bool recordingVoice;

  /// Aviso de modalidad: si el modelo efectivo (elegido o, en su defecto, el
  /// default) declara NO ver imágenes/PDF y hay un pendiente de ese tipo, una
  /// línea honesta advierte que viajará como texto sustituto. Flags ausentes
  /// (wire viejo) ⇒ '' (degradación limpia, sin aviso).
  String get modalityWarning {
    if (pendingAttachments.isEmpty) return '';
    final effId = selectedModelId.isNotEmpty ? selectedModelId : defaultModelId;
    if (effId.isEmpty) return '';
    PaModelOption? opt;
    for (final m in models) {
      if (m.id == effId) {
        opt = m;
        break;
      }
    }
    if (opt == null) return '';
    final hasImage = pendingAttachments.any((a) => a.mime.startsWith('image/'));
    final hasPdf = pendingAttachments.any((a) => a.mime == 'application/pdf');
    final warnImage = hasImage && opt.imageInput == false;
    final warnPdf = hasPdf && opt.pdfInput == false;
    if (warnImage && warnPdf) {
      return 'Este modelo no ve imágenes ni PDF; viajarán como texto sustituto.';
    }
    if (warnImage) {
      return 'Este modelo no ve imágenes; viajarán como texto sustituto.';
    }
    if (warnPdf) {
      return 'Este modelo no ve PDF; viajará como texto sustituto.';
    }
    return '';
  }

  PaChatLoaded copyWith({
    List<PaConversation>? conversations,
    PaConversation? activeConversation,
    List<PaMessage>? messages,
    bool? sending,
    PaFailure? sendFailure,
    bool clearSendFailure = false,
    List<PaProgressEvent>? liveEvents,
    bool? livePartial,
    bool? liveStopped,
    String? selectedModelId,
    String? nextCursor,
    bool? loadingMore,
    String? lastAttemptedContent,
    String? draft,
    List<PaAttachment>? pendingAttachments,
    Map<String, Uint8List>? pendingThumbnails,
    bool? attaching,
    bool? recordingVoice,
  }) => PaChatLoaded(
    conversations: conversations ?? this.conversations,
    activeConversation: activeConversation ?? this.activeConversation,
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    sendFailure: clearSendFailure ? null : (sendFailure ?? this.sendFailure),
    liveEvents: liveEvents ?? this.liveEvents,
    livePartial: livePartial ?? this.livePartial,
    liveStopped: liveStopped ?? this.liveStopped,
    models: models,
    defaultModelId: defaultModelId,
    selectedModelId: selectedModelId ?? this.selectedModelId,
    nextCursor: nextCursor ?? this.nextCursor,
    loadingMore: loadingMore ?? this.loadingMore,
    lastAttemptedContent: lastAttemptedContent ?? this.lastAttemptedContent,
    draft: draft ?? this.draft,
    pendingAttachments: pendingAttachments ?? this.pendingAttachments,
    pendingThumbnails: pendingThumbnails ?? this.pendingThumbnails,
    attaching: attaching ?? this.attaching,
    recordingVoice: recordingVoice ?? this.recordingVoice,
  );

  @override
  bool operator ==(Object other) =>
      other is PaChatLoaded &&
      listEquals(other.conversations, conversations) &&
      other.activeConversation == activeConversation &&
      listEquals(other.messages, messages) &&
      other.sending == sending &&
      other.sendFailure == sendFailure &&
      listEquals(other.liveEvents, liveEvents) &&
      other.livePartial == livePartial &&
      other.liveStopped == liveStopped &&
      listEquals(other.models, models) &&
      other.defaultModelId == defaultModelId &&
      other.selectedModelId == selectedModelId &&
      other.nextCursor == nextCursor &&
      other.loadingMore == loadingMore &&
      other.lastAttemptedContent == lastAttemptedContent &&
      other.draft == draft &&
      listEquals(other.pendingAttachments, pendingAttachments) &&
      mapEquals(other.pendingThumbnails, pendingThumbnails) &&
      other.attaching == attaching &&
      other.recordingVoice == recordingVoice;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(conversations),
    activeConversation,
    Object.hashAll(messages),
    sending,
    sendFailure,
    Object.hashAll(liveEvents),
    livePartial,
    liveStopped,
    Object.hashAll(models),
    defaultModelId,
    selectedModelId,
    nextCursor,
    loadingMore,
    lastAttemptedContent,
    draft,
    Object.hashAll(pendingAttachments),
    Object.hashAll(pendingThumbnails.keys),
    attaching,
    recordingVoice,
  );
}

class PlatformAgentChatBloc extends Bloc<PaChatEvent, PaChatState> {
  PlatformAgentChatBloc({
    required PlatformAgentRepository repo,
    required PlatformAgentEvents events,
    MediaFilePicker? picker,
    MediaByteSink? mediaSink,
  }) : _repo = repo,
       _events = events,
       _picker = picker,
       _mediaSink = mediaSink,
       super(const PaChatLoading()) {
    on<PaChatStarted>(_onStarted);
    on<PaChatDraftSeeded>(_onDraftSeeded);
    on<PaChatMessageSent>(_onMessageSent);
    on<PaChatAttachRequested>(_onAttachRequested);
    on<PaChatAttachmentRemoved>(_onAttachmentRemoved);
    on<PaChatNewConversationRequested>(_onNewConversation);
    on<PaChatLoadMore>(_onLoadMore);
    on<PaChatConversationRenamed>(_onConversationRenamed);
    on<PaChatConversationDeleted>(_onConversationDeleted);
    on<PaChatConversationSelected>(_onConversationSelected);
    on<PaChatProgressReceived>(_onProgressReceived);
    on<PaChatModelSelected>(_onModelSelected);
    on<PaChatTurnCancelRequested>(_onTurnCancelRequested);
    on<PaChatDraftChanged>(_onDraftChanged);
    on<PaChatVoiceStarted>(_onVoiceStarted);
    on<PaChatVoiceCancelled>(_onVoiceCancelled);
    on<PaChatVoiceSent>(_onVoiceSent);
  }

  final PlatformAgentRepository _repo;
  final PlatformAgentEvents _events;

  /// Picker de archivos (nil ⇒ el composer oculta el clip — DX/tests).
  final MediaFilePicker? _picker;

  /// Caché local donde sembrar los bytes de un adjunto recién subido (o de la
  /// nota de voz recién grabada) bajo su ref definitiva: el wire del asistente
  /// no trae URL firmada, así que la burbuja enviada solo puede
  /// pintarse/reproducirse desde esta copia. nil ⇒ sin siembra (la burbuja
  /// degrada a la tarjeta con nombre / audio sin fuente).
  final MediaByteSink? _mediaSink;

  /// Máximo de adjuntos por turno (server-side) y peso por archivo. Se aplican
  /// client-side ANTES de subir para no gastar red en lo que el server rechaza.
  static const int _maxAttachments = 5;
  static const int _maxAttachmentBytes = 25 * 1024 * 1024;

  /// Espejo client-side de la allowlist de content-types del servidor
  /// (imagen JPG/PNG/WebP, PDF y video MP4), expresada como extensiones porque
  /// el picker solo entrega bytes + filename. Gate rápido para no subir lo que
  /// el server contestaría 415; el server sigue siendo la autoridad (sniffea
  /// los bytes reales).
  static const Set<String> _allowedAttachmentExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
    'mp4',
  };

  static bool _isSupportedAttachment(PickedMedia p) {
    final name = p.filename;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return false;
    return _allowedAttachmentExtensions.contains(
      name.substring(dot + 1).toLowerCase(),
    );
  }

  /// Borradores del composer por conversationId (en memoria): sobreviven el
  /// cambio de pestaña del shell, que destruye el estado del composer.
  final Map<String, String> _drafts = <String, String>{};
  String _pendingSeed = '';

  /// Borrador vigente del hilo activo. La página lo lee al (re)montarse —p.ej.
  /// al volver a la pestaña del shell, que destruye y recrea el composer— porque
  /// _drafts es la verdad viva (se actualiza en cada tecla), mientras state.draft
  /// solo se refresca en transiciones puntuales (selección de hilo, cancelación).
  String get activeDraft {
    final s = state;
    if (s is PaChatLoaded) return _drafts[s.activeConversation.id] ?? s.draft;
    return '';
  }

  /// true entre que el operador pide cancelar y que el POST abortado lanza:
  /// la guarda hace que el catch del envío trague la excepción de cancelación
  /// en vez de pintarla como fallo real.
  bool _cancelRequested = false;

  /// Suscripción de progreso del turno en vuelo (per-turn): se abre al enviar
  /// y se cancela al volver el POST o al cerrarse el bloc.
  StreamSubscription<PaProgressEvent>? _progressSub;

  @override
  Future<void> close() {
    // Cancelar una suscripción SSE viva aguarda el desmonte del socket, que
    // puede no completar; el cierre del bloc no debe colgarse en él.
    unawaited(_progressSub?.cancel());
    return super.close();
  }

  Future<({List<PaMessage> messages, String nextCursor})> _loadMessages(
    String conversationId,
  ) async {
    final page = await _repo.listMessages(
      conversationId: conversationId,
      limit: _pageLimit,
    );
    // El wire entrega DESC (recientes primero); el hilo renderiza ASC.
    return (
      messages: page.messages.reversed.toList(growable: false),
      nextCursor: page.nextCursor,
    );
  }

  /// Allowlist de modelos, best-effort: el selector es accesorio — CUALQUIER
  /// fallo (backend sin la ruta, red, wire inesperado) lo oculta sin tocar la
  /// carga del hilo.
  Future<PaModels> _loadModels() async {
    try {
      return await _repo.listModels();
    } on Object {
      return const PaModels(options: <PaModelOption>[], defaultId: '');
    }
  }

  Future<void> _onStarted(
    PaChatStarted event,
    Emitter<PaChatState> emit,
  ) async {
    emit(const PaChatLoading());
    try {
      final convs = await _repo.listConversations();
      final active = convs.isNotEmpty
          ? convs.first
          : await _repo.createConversation(title: _newTitle);
      final list = convs.isNotEmpty ? convs : <PaConversation>[active];
      final models = await _loadModels();
      final page = await _loadMessages(active.id);
      final seed = _pendingSeed;
      _pendingSeed = '';
      if (seed.isNotEmpty) _drafts[active.id] = seed;
      emit(
        PaChatLoaded(
          conversations: list,
          activeConversation: active,
          messages: page.messages,
          nextCursor: page.nextCursor,
          sending: false,
          models: models.options,
          defaultModelId: models.defaultId,
          draft: seed,
        ),
      );
    } on PaFailure catch (f) {
      emit(PaChatFailed(f));
    }
  }

  Future<void> _onMessageSent(
    PaChatMessageSent event,
    Emitter<PaChatState> emit,
  ) async {
    final current = state;
    // El envío se rechaza mientras un lote de adjuntos sube: capturar el estado
    // a mitad de subida enviaría un subconjunto y, al limpiar los pendientes con
    // ese estado stale, dejaría los archivos que aún subían huérfanos en storage.
    // El operador reenvía cuando la subida cierra.
    if (current is! PaChatLoaded ||
        current.sending ||
        current.attaching ||
        current.recordingVoice) {
      return;
    }
    final convId = current.activeConversation.id;
    final turnBase = _withIntentTitle(current, event.content);
    _cancelRequested = false;
    _drafts.remove(convId);
    final optimistic = PaMessage(
      id: 'optimistic',
      conversationId: convId,
      role: 'user',
      content: event.content,
      attachments: current.pendingAttachments,
      createdAt: DateTime.now().toUtc(),
    );
    emit(
      current.copyWith(
        conversations: turnBase.conversations,
        activeConversation: turnBase.activeConversation,
        messages: <PaMessage>[...turnBase.messages, optimistic],
        sending: true,
        liveEvents: const <PaProgressEvent>[],
        livePartial: false,
        liveStopped: false,
        clearSendFailure: true,
        lastAttemptedContent: event.content,
        draft: '',
      ),
    );
    // Indicador en vivo: suscripción de progreso per-turn. Best-effort —
    // cosmético; si el SSE no conecta, el indicador se queda en "Pensando…".
    // El cancel NO se espera: cancelar una suscripción SSE viva aguarda el
    // desmonte del socket (que el server mantiene abierto) y puede no completar
    // — esperarlo colgaría el cierre del turno en "Pensando…" sin salida.
    unawaited(_progressSub?.cancel());
    _progressSub = _events.progress(convId).listen((e) {
      if (!isClosed) add(PaChatProgressReceived(e));
    }, onError: (Object _) {});
    try {
      final assistant = await _repo.sendMessage(
        conversationId: convId,
        content: event.content,
        model: current.selectedModelId.isEmpty ? null : current.selectedModelId,
        attachments: current.pendingAttachments
            .map((a) => a.ref)
            .toList(growable: false),
      );
      unawaited(_progressSub?.cancel());
      _progressSub = null;
      // El POST síncrono YA devolvió el assistant final: cerramos el turno de
      // INMEDIATO (sending=false con el hilo en mano). Invariante: una vez que
      // el POST vuelve, NADA — ni el cancel del SSE ni la recarga — puede
      // bloquear este cierre, o el chat se queda en "Pensando…".
      //
      // Cierra releyendo el state actual, no el snapshot pre-turno `current`:
      // un cambio de modelo (u otra edición sin guarda de sending) ocurrido
      // mid-turno vive en el state vivo y no debe pisarse. Si el state ya no
      // es este hilo (cambió de conversación), se reconstruye desde `current`.
      final closing = state;
      if (closing is PaChatLoaded && closing.activeConversation.id == convId) {
        // liveEvents se CONSERVA: la traza viva sigue pintada (sin latido)
        // hasta que la recarga triunfe (swap) o falle (marcada parcial).
        emit(
          closing.copyWith(
            messages: <PaMessage>[...closing.messages, assistant],
            sending: false,
            livePartial: false,
            liveStopped: false,
            clearSendFailure: true,
            lastAttemptedContent: '',
            pendingAttachments: const <PaAttachment>[],
            pendingThumbnails: const <String, Uint8List>{},
          ),
        );
      } else {
        emit(
          turnBase.copyWith(
            messages: <PaMessage>[...turnBase.messages, optimistic, assistant],
            sending: false,
            liveEvents: const <PaProgressEvent>[],
            livePartial: false,
            liveStopped: false,
            clearSendFailure: true,
            lastAttemptedContent: '',
            pendingAttachments: const <PaAttachment>[],
            pendingThumbnails: const <String, Uint8List>{},
          ),
        );
      }
      // Recarga best-effort (follow-up, ya con el turno cerrado): trae el hilo
      // completo del server, incl. los mensajes de tool que el POST no devuelve.
      await _reloadThread(emit, convId, assistant.id);
      await _refreshConversations(emit, convId);
    } on PaFailure catch (f) {
      unawaited(_progressSub?.cancel());
      _progressSub = null;
      // El turno se canceló: el handler de cancelación ya dejó el estado limpio
      // (optimista revertido, sending=false). Tragamos la excepción del POST
      // abortado en vez de pintarla como fallo.
      if (_cancelRequested) {
        _cancelRequested = false;
        return;
      }
      // Revertir el optimista: el 502 deja el user message fuera del hilo
      // (reintentable); conservamos el texto para que "Reintentar" lo
      // recupere. Igual que el cierre exitoso, se relee el state actual (un
      // cambio de modelo mid-turno no debe pisarse); si ya es otro hilo, se
      // reconstruye desde el snapshot pre-optimista `current`.
      final failing = state;
      if (failing is PaChatLoaded && failing.activeConversation.id == convId) {
        emit(
          failing.copyWith(
            messages: failing.messages
                .where((m) => m.id != 'optimistic')
                .toList(growable: false),
            sending: false,
            liveEvents: const <PaProgressEvent>[],
            livePartial: false,
            liveStopped: false,
            sendFailure: f,
            lastAttemptedContent: event.content,
          ),
        );
      } else {
        emit(
          turnBase.copyWith(
            sending: false,
            liveEvents: const <PaProgressEvent>[],
            livePartial: false,
            liveStopped: false,
            sendFailure: f,
            lastAttemptedContent: event.content,
          ),
        );
      }
    }
  }

  PaChatLoaded _withIntentTitle(PaChatLoaded state, String intent) {
    if (state.activeConversation.title.trim().isNotEmpty) return state;
    final fallback = _intentTitle(intent);
    if (fallback.isEmpty) return state;
    final updated = PaConversation(
      id: state.activeConversation.id,
      title: fallback,
      createdAt: state.activeConversation.createdAt,
      updatedAt: state.activeConversation.updatedAt,
    );
    return state.copyWith(
      activeConversation: updated,
      conversations: state.conversations
          .map((c) => c.id == updated.id ? updated : c)
          .toList(growable: false),
    );
  }

  static String _intentTitle(String input) {
    final clean = input
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9À-ÿ_-]+'), ' ')
        .trim();
    if (clean.isEmpty) return '';
    final words = clean.split(RegExp(r'\s+')).take(7).join(' ');
    return words.length <= 64 ? words : '${words.substring(0, 63)}…';
  }

  /// Marca parcial la traza viva del turno recién cerrado: la recarga falló o
  /// llegó rezagada y esos eventos son el único registro del proceso. Solo si
  /// el hilo pintado sigue siendo el mismo y no arrancó un turno nuevo — una
  /// recarga vieja no puede estampar «parcial» a la traza de un turno ajeno.
  void _markLivePartial(Emitter<PaChatState> emit, String conversationId) {
    if (isClosed) return;
    final s = state;
    if (s is! PaChatLoaded ||
        s.activeConversation.id != conversationId ||
        s.sending ||
        s.liveEvents.isEmpty) {
      return;
    }
    emit(s.copyWith(livePartial: true));
  }

  /// Recarga el hilo tras cerrar un turno, para sumar los mensajes de tool que
  /// el POST síncrono no devuelve. Best-effort y NO bloqueante del cierre (se
  /// llama DESPUÉS de emitir sending=false): si triunfa hace el swap (descarta
  /// la traza viva); si falla, llega rezagada (sin ver el turno recién
  /// escrito) deja la viva marcada parcial; si el operador ya cambió de hilo,
  /// no se aplica — nunca pisa un hilo que el operador ya tiene abierto.
  Future<void> _reloadThread(
    Emitter<PaChatState> emit,
    String conversationId,
    String assistantId,
  ) async {
    ({List<PaMessage> messages, String nextCursor}) reloaded;
    try {
      reloaded = await _loadMessages(conversationId);
    } on Object {
      _markLivePartial(emit, conversationId);
      return;
    }
    if (!reloaded.messages.any((m) => m.id == assistantId)) {
      _markLivePartial(emit, conversationId); // recarga rezagada
      return;
    }
    if (isClosed) return;
    final s = state;
    if (s is! PaChatLoaded ||
        s.activeConversation.id != conversationId ||
        s.sending) {
      return;
    }
    // Swap: llegó la verdad persistida; la traza viva ya no hace falta.
    emit(
      s.copyWith(
        messages: reloaded.messages,
        nextCursor: reloaded.nextCursor,
        liveEvents: const <PaProgressEvent>[],
        livePartial: false,
      ),
    );
  }

  Future<void> _refreshConversations(
    Emitter<PaChatState> emit,
    String activeId,
  ) async {
    List<PaConversation> fresh;
    try {
      fresh = await _repo.listConversations();
    } on Object {
      return;
    }
    if (isClosed) return;
    final current = state;
    if (current is! PaChatLoaded ||
        current.activeConversation.id != activeId ||
        current.sending) {
      return;
    }
    // Si el modelo aún no terminó, conservar el título optimista local en vez
    // de volver a una fila vacía. La próxima recarga toma el título persistido.
    final merged = fresh
        .map((c) {
          if (c.title.trim().isNotEmpty) return c;
          for (final local in current.conversations) {
            if (local.id == c.id && local.title.trim().isNotEmpty) return local;
          }
          return c;
        })
        .toList(growable: false);
    PaConversation? active;
    for (final c in merged) {
      if (c.id == activeId) active = c;
    }
    if (active == null) return;
    emit(current.copyWith(conversations: merged, activeConversation: active));
  }

  void _onProgressReceived(
    PaChatProgressReceived event,
    Emitter<PaChatState> emit,
  ) {
    final current = state;
    if (current is! PaChatLoaded || !current.sending) return;
    if (event.event.conversationId != current.activeConversation.id) return;
    // Acumula el frame crudo: la traza viva lo interpreta (nodeFromProgress).
    // Los terminales también se guardan —el `failed` aporta la causa del
    // fallo al resumen—; el cierre del POST descarta toda la lista.
    emit(
      current.copyWith(
        liveEvents: <PaProgressEvent>[...current.liveEvents, event.event],
      ),
    );
  }

  Future<void> _onNewConversation(
    PaChatNewConversationRequested event,
    Emitter<PaChatState> emit,
  ) async {
    final preserved = state is PaChatLoaded ? state as PaChatLoaded : null;
    try {
      final conv = await _repo.createConversation(title: _newTitle);
      final convs = preserved != null
          ? <PaConversation>[conv, ...preserved.conversations]
          : <PaConversation>[conv];
      // El selector de modelo es de la pantalla, no del hilo: debe sobrevivir
      // al iniciar una conversación nueva (heredado del estado vivo; si no lo
      // había, se recarga best-effort).
      final models = preserved != null
          ? PaModels(
              options: preserved.models,
              defaultId: preserved.defaultModelId,
            )
          : await _loadModels();
      emit(
        PaChatLoaded(
          conversations: convs,
          activeConversation: conv,
          messages: const <PaMessage>[],
          sending: false,
          models: models.options,
          defaultModelId: models.defaultId,
          selectedModelId: preserved?.selectedModelId ?? '',
        ),
      );
    } on PaFailure catch (f) {
      emit(PaChatFailed(f));
    }
  }

  Future<void> _onConversationSelected(
    PaChatConversationSelected event,
    Emitter<PaChatState> emit,
  ) async {
    final current = state;
    if (current is! PaChatLoaded || current.sending) return;
    if (event.id == current.activeConversation.id) return;
    PaConversation? target;
    for (final c in current.conversations) {
      if (c.id == event.id) {
        target = c;
        break;
      }
    }
    if (target == null) return;
    try {
      final page = await _loadMessages(target.id);
      // Los adjuntos pendientes son del hilo que se abandona: cambiar de hilo
      // los descarta (no se arrastran a otra conversación).
      emit(
        current.copyWith(
          activeConversation: target,
          messages: page.messages,
          nextCursor: page.nextCursor,
          liveEvents: const <PaProgressEvent>[],
          livePartial: false,
          liveStopped: false,
          clearSendFailure: true,
          draft: _drafts[target.id] ?? '',
          pendingAttachments: const <PaAttachment>[],
          pendingThumbnails: const <String, Uint8List>{},
        ),
      );
    } on PaFailure catch (f) {
      emit(current.copyWith(sendFailure: f));
    }
  }

  Future<void> _onLoadMore(
    PaChatLoadMore event,
    Emitter<PaChatState> emit,
  ) async {
    final current = state;
    if (current is! PaChatLoaded ||
        current.loadingMore ||
        current.sending ||
        current.nextCursor.isEmpty) {
      return;
    }
    emit(current.copyWith(loadingMore: true));
    try {
      final page = await _repo.listMessages(
        conversationId: current.activeConversation.id,
        cursor: current.nextCursor,
        limit: _pageLimit,
      );
      final after = state;
      if (after is! PaChatLoaded) return;
      // El wire del tramo viejo viene DESC; invertir a ASC y ANTEPONER.
      final older = page.messages.reversed.toList(growable: false);
      emit(
        after.copyWith(
          messages: <PaMessage>[...older, ...after.messages],
          nextCursor: page.nextCursor,
          loadingMore: false,
        ),
      );
    } on PaFailure {
      final after = state;
      if (after is! PaChatLoaded) return;
      emit(after.copyWith(loadingMore: false));
    }
  }

  Future<void> _onConversationRenamed(
    PaChatConversationRenamed event,
    Emitter<PaChatState> emit,
  ) async {
    final current = state;
    if (current is! PaChatLoaded) return;
    try {
      final updated = await _repo.renameConversation(event.id, event.title);
      emit(
        current.copyWith(
          conversations: current.conversations
              .map((c) => c.id == updated.id ? updated : c)
              .toList(growable: false),
          activeConversation: current.activeConversation.id == updated.id
              ? updated
              : current.activeConversation,
        ),
      );
    } on PaFailure catch (f) {
      emit(current.copyWith(sendFailure: f));
    }
  }

  Future<void> _onConversationDeleted(
    PaChatConversationDeleted event,
    Emitter<PaChatState> emit,
  ) async {
    final current = state;
    if (current is! PaChatLoaded) return;
    try {
      await _repo.deleteConversation(event.id);
      final remaining = current.conversations
          .where((c) => c.id != event.id)
          .toList(growable: false);
      // Borró un hilo NO activo: basta quitarlo de la lista.
      if (event.id != current.activeConversation.id) {
        emit(current.copyWith(conversations: remaining));
        return;
      }
      // Borró el ACTIVO: si quedan hilos, abre el más reciente; si no, crea uno.
      if (remaining.isEmpty) {
        final fresh = await _repo.createConversation(title: _newTitle);
        emit(
          current.copyWith(
            conversations: <PaConversation>[fresh],
            activeConversation: fresh,
            messages: const <PaMessage>[],
            nextCursor: '',
            liveEvents: const <PaProgressEvent>[],
            livePartial: false,
            liveStopped: false,
            clearSendFailure: true,
            pendingAttachments: const <PaAttachment>[],
            pendingThumbnails: const <String, Uint8List>{},
          ),
        );
        return;
      }
      final next = remaining.first;
      final page = await _loadMessages(next.id);
      emit(
        current.copyWith(
          conversations: remaining,
          activeConversation: next,
          messages: page.messages,
          nextCursor: page.nextCursor,
          liveEvents: const <PaProgressEvent>[],
          livePartial: false,
          liveStopped: false,
          clearSendFailure: true,
          pendingAttachments: const <PaAttachment>[],
          pendingThumbnails: const <String, Uint8List>{},
        ),
      );
    } on PaFailure catch (f) {
      emit(current.copyWith(sendFailure: f));
    }
  }

  Future<void> _onAttachRequested(
    PaChatAttachRequested event,
    Emitter<PaChatState> emit,
  ) async {
    final current = state;
    final picker = _picker;
    if (current is! PaChatLoaded || picker == null || current.attaching) return;
    final picked = await picker.pickMultiple();
    if (picked.isEmpty) return; // canceló o nada con bytes.
    final afterPick = state;
    if (afterPick is! PaChatLoaded) return;

    // Partición client-side: descartar tipos fuera de la allowlist, luego
    // sobre-peso, luego acotar al cupo restante (5 CONTANDO los pendientes
    // ya subidos).
    final withinSize = <PickedMedia>[];
    var anyUnsupported = false;
    var anyTooLarge = false;
    for (final p in picked) {
      if (!_isSupportedAttachment(p)) {
        anyUnsupported = true;
      } else if (p.bytes.length > _maxAttachmentBytes) {
        anyTooLarge = true;
      } else {
        withinSize.add(p);
      }
    }
    final remaining = _maxAttachments - afterPick.pendingAttachments.length;
    final toUpload = remaining > 0
        ? withinSize.take(remaining).toList(growable: false)
        : const <PickedMedia>[];
    final anyOverLimit = withinSize.length > toUpload.length;

    if (toUpload.isEmpty) {
      // Nada subible: informar el motivo dominante (tipo > peso > cupo).
      emit(
        afterPick.copyWith(
          sendFailure: anyUnsupported
              ? const PaAttachmentUnsupportedFailure()
              : anyTooLarge
              ? const PaAttachmentTooLargeFailure()
              : const PaAttachmentLimitFailure(),
        ),
      );
      return;
    }

    emit(afterPick.copyWith(attaching: true, clearSendFailure: true));
    for (final p in toUpload) {
      try {
        final att = await _repo.uploadAttachment(
          bytes: p.bytes,
          filename: p.filename,
        );
        // Siembra la copia local bajo la ref definitiva: la burbuja del turno
        // enviado se pinta/reproduce desde caché (el wire no trae URL firmada).
        // Best-effort y no bloqueante de la subida del lote.
        final sink = _mediaSink;
        if (sink != null) unawaited(sink.cache(att.ref, p.bytes));
        final cur = state;
        if (cur is! PaChatLoaded) return;
        // La miniatura local solo aplica a imágenes; el resto usa ícono.
        final thumbs = att.mime.startsWith('image/')
            ? <String, Uint8List>{...cur.pendingThumbnails, att.ref: p.bytes}
            : null;
        emit(
          cur.copyWith(
            pendingAttachments: <PaAttachment>[...cur.pendingAttachments, att],
            pendingThumbnails: thumbs,
          ),
        );
      } on PaFailure catch (f) {
        final cur = state;
        if (cur is! PaChatLoaded) return;
        // Corta el lote en la primera falla de red/servidor y la muestra.
        emit(cur.copyWith(attaching: false, sendFailure: f));
        return;
      }
    }

    final cur = state;
    if (cur is! PaChatLoaded) return;
    // Cierre del lote: si algo se descartó client-side, informarlo (tipo >
    // peso > cupo); si todo entró, limpiar cualquier aviso previo.
    final notice = anyUnsupported
        ? const PaAttachmentUnsupportedFailure()
        : anyTooLarge
        ? const PaAttachmentTooLargeFailure()
        : (anyOverLimit ? const PaAttachmentLimitFailure() : null);
    emit(
      cur.copyWith(
        attaching: false,
        sendFailure: notice,
        clearSendFailure: notice == null,
      ),
    );
  }

  void _onAttachmentRemoved(
    PaChatAttachmentRemoved event,
    Emitter<PaChatState> emit,
  ) {
    final current = state;
    if (current is! PaChatLoaded) return;
    emit(
      current.copyWith(
        pendingAttachments: current.pendingAttachments
            .where((a) => a.ref != event.ref)
            .toList(growable: false),
        pendingThumbnails: <String, Uint8List>{...current.pendingThumbnails}
          ..remove(event.ref),
      ),
    );
  }

  void _onModelSelected(PaChatModelSelected event, Emitter<PaChatState> emit) {
    final current = state;
    if (current is! PaChatLoaded) return;
    emit(current.copyWith(selectedModelId: event.modelId));
  }

  void _onTurnCancelRequested(
    PaChatTurnCancelRequested event,
    Emitter<PaChatState> emit,
  ) {
    final current = state;
    if (current is! PaChatLoaded || !current.sending) return;
    _cancelRequested = true;
    _repo.cancelSend();
    unawaited(_progressSub?.cancel());
    _progressSub = null;
    // Devolver el texto cancelado al borrador para que el operador lo reedite.
    final cancelled = current.lastAttemptedContent;
    if (cancelled.isNotEmpty) {
      _drafts[current.activeConversation.id] = cancelled;
    }
    // liveEvents se CONSERVA y liveStopped ancla la traza en pantalla,
    // colapsada al copy honesto: el cancel es solo del cliente y el servidor
    // pudo continuar — desaparecerla afirmaría que el turno nunca ocurrió.
    emit(
      current.copyWith(
        messages: current.messages
            .where((m) => m.id != 'optimistic')
            .toList(growable: false),
        sending: false,
        liveStopped: true,
        clearSendFailure: true,
        draft: cancelled,
      ),
    );
  }

  void _onVoiceStarted(PaChatVoiceStarted event, Emitter<PaChatState> emit) {
    final current = state;
    // No arrancar sobre un turno en vuelo, una subida de adjuntos, ni una
    // grabación ya activa (una cosa a la vez).
    if (current is! PaChatLoaded ||
        current.sending ||
        current.attaching ||
        current.recordingVoice) {
      return;
    }
    emit(current.copyWith(recordingVoice: true, clearSendFailure: true));
  }

  void _onVoiceCancelled(
    PaChatVoiceCancelled event,
    Emitter<PaChatState> emit,
  ) {
    final current = state;
    if (current is! PaChatLoaded || !current.recordingVoice) return;
    emit(current.copyWith(recordingVoice: false));
  }

  /// Corre el turno de una nota de voz: sube el clip vía sendAudio y cierra con
  /// el assistant final, reusando la máquina del turno de texto (sending/typing/
  /// SSE/recarga). No hay burbuja optimista del user (el audio aún no tiene ref;
  /// el user con su transcript llega en la recarga) ni reintento (el clip ya no
  /// está en mano tras enviarlo).
  Future<void> _onVoiceSent(
    PaChatVoiceSent event,
    Emitter<PaChatState> emit,
  ) async {
    final current = state;
    // Sin grabación en curso no hay clip que enviar: un VoiceSent espurio (sin
    // el VoiceStarted previo) no debe correr un turno de audio. Espeja la guarda
    // de _onVoiceStarted (que ignora arrancar sobre una grabación ya activa).
    if (current is! PaChatLoaded ||
        current.sending ||
        current.attaching ||
        !current.recordingVoice) {
      return;
    }
    final convId = current.activeConversation.id;
    _cancelRequested = false;
    emit(
      current.copyWith(
        recordingVoice: false,
        sending: true,
        liveEvents: const <PaProgressEvent>[],
        livePartial: false,
        liveStopped: false,
        clearSendFailure: true,
        lastAttemptedContent: '',
      ),
    );
    unawaited(_progressSub?.cancel());
    _progressSub = _events.progress(convId).listen((e) {
      if (!isClosed) add(PaChatProgressReceived(e));
    }, onError: (Object _) {});
    try {
      final assistant = await _repo.sendAudio(
        conversationId: convId,
        bytes: event.bytes,
        filename: event.filename,
      );
      unawaited(_progressSub?.cancel());
      _progressSub = null;
      // Cierre releyendo el state actual (cambio de modelo mid-turno no se
      // pisa); liveEvents se conserva hasta el swap de la recarga — igual que
      // el turno de texto.
      final closing = state;
      if (closing is PaChatLoaded && closing.activeConversation.id == convId) {
        emit(
          closing.copyWith(
            messages: <PaMessage>[...closing.messages, assistant],
            recordingVoice: false,
            sending: false,
            livePartial: false,
            liveStopped: false,
            clearSendFailure: true,
          ),
        );
      } else {
        emit(
          current.copyWith(
            messages: <PaMessage>[...current.messages, assistant],
            recordingVoice: false,
            sending: false,
            liveEvents: const <PaProgressEvent>[],
            livePartial: false,
            liveStopped: false,
            clearSendFailure: true,
          ),
        );
      }
      // Recarga best-effort: trae el user de voz (con su transcript) y los
      // mensajes de tool que el POST no devuelve.
      await _reloadThread(emit, convId, assistant.id);
      _seedVoiceBytes(event.bytes);
    } on PaFailure catch (f) {
      unawaited(_progressSub?.cancel());
      _progressSub = null;
      // El turno se canceló: el handler de cancelación ya dejó el estado limpio.
      if (_cancelRequested) {
        _cancelRequested = false;
        return;
      }
      final failing = state;
      if (failing is PaChatLoaded && failing.activeConversation.id == convId) {
        emit(
          failing.copyWith(
            recordingVoice: false,
            sending: false,
            liveEvents: const <PaProgressEvent>[],
            livePartial: false,
            liveStopped: false,
            sendFailure: f,
          ),
        );
      } else {
        emit(
          current.copyWith(
            recordingVoice: false,
            sending: false,
            liveEvents: const <PaProgressEvent>[],
            livePartial: false,
            liveStopped: false,
            sendFailure: f,
          ),
        );
      }
    }
  }

  /// Siembra los bytes recién grabados bajo el `audio_ref` del user de voz que
  /// la recarga trajo (el más reciente del hilo): así la burbuja reproduce
  /// desde la copia local, porque el wire no trae URL firmada. Sin recarga
  /// (falló / el operador cambió de hilo) no hay ref conocida y se omite
  /// (degradación honesta a audio sin fuente).
  void _seedVoiceBytes(Uint8List bytes) {
    final sink = _mediaSink;
    final s = state;
    if (sink == null || s is! PaChatLoaded) return;
    for (final m in s.messages.reversed) {
      if (m.isUser && m.audioRef.isNotEmpty) {
        unawaited(sink.cache(m.audioRef, bytes));
        return;
      }
    }
  }

  void _onDraftChanged(PaChatDraftChanged event, Emitter<PaChatState> emit) {
    final current = state;
    if (current is! PaChatLoaded) return;
    // Persistir sin re-emitir: el composer es la fuente de verdad mientras el
    // hilo está abierto; el borrador se siembra al cambiar de hilo o cancelar.
    _drafts[current.activeConversation.id] = event.text;
  }

  void _onDraftSeeded(PaChatDraftSeeded event, Emitter<PaChatState> emit) {
    final text = event.text.trimRight();
    if (text.isEmpty) return;
    final current = state;
    if (current is! PaChatLoaded) {
      _pendingSeed = text;
      return;
    }
    _drafts[current.activeConversation.id] = text;
    emit(current.copyWith(draft: text));
  }
}
