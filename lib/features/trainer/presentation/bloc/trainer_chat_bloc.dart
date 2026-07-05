import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/media/media_byte_sink.dart';
import '../../domain/entities/trainer_attachment.dart';
import '../../domain/entities/trainer_conversation.dart';
import '../../domain/entities/trainer_message.dart';
import '../../domain/entities/trainer_models.dart';
import '../../domain/entities/trainer_progress.dart';
import '../../domain/failures/trainer_failure.dart';
import '../../../media/domain/repositories/media_file_picker.dart';
import '../../domain/repositories/trainer_repositories.dart';

/// Página de historial que el chat carga por turno. El POST síncrono ya
/// devuelve el assistant final, pero el hilo completo (tool results para
/// las tarjetas de cambio) vive en el server: tras cada turno se RECARGA.
const int _pageLimit = 50;

sealed class TrainerChatEvent {
  const TrainerChatEvent();
}

final class TrainerChatStarted extends TrainerChatEvent {
  const TrainerChatStarted();
}

final class TrainerChatMessageSent extends TrainerChatEvent {
  const TrainerChatMessageSent(this.content);

  final String content;

  @override
  bool operator ==(Object other) =>
      other is TrainerChatMessageSent && other.content == content;

  @override
  int get hashCode => content.hashCode;
}

final class TrainerChatNewConversationRequested extends TrainerChatEvent {
  const TrainerChatNewConversationRequested();
}

/// El operador elige otro hilo del selector.
final class TrainerChatConversationSelected extends TrainerChatEvent {
  const TrainerChatConversationSelected(this.id);

  final String id;

  @override
  bool operator ==(Object other) =>
      other is TrainerChatConversationSelected && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// El operador elige el modelo del entrenador para los próximos turnos.
/// id vacío ⇒ volver al default de la plataforma (el turno viaja sin model).
/// El operador quiere adjuntar un archivo al turno: abre el picker y, si
/// elige, lo sube al hilo (la ref queda PENDIENTE hasta el send).
final class TrainerChatAttachRequested extends TrainerChatEvent {
  const TrainerChatAttachRequested();
}

/// Quita un adjunto pendiente (por ref) antes de enviar.
final class TrainerChatAttachmentRemoved extends TrainerChatEvent {
  const TrainerChatAttachmentRemoved(this.ref);

  final String ref;
}

final class TrainerChatModelSelected extends TrainerChatEvent {
  const TrainerChatModelSelected(this.modelId);

  final String modelId;

  @override
  bool operator ==(Object other) =>
      other is TrainerChatModelSelected && other.modelId == modelId;

  @override
  int get hashCode => modelId.hashCode;
}

/// El operador detiene el turno en vuelo: aborta el POST y revierte el optimista.
final class TrainerChatTurnCancelRequested extends TrainerChatEvent {
  const TrainerChatTurnCancelRequested();
}

/// Empieza a grabar una nota de voz (bloquea el envío de texto: una a la vez).
final class TrainerChatVoiceStarted extends TrainerChatEvent {
  const TrainerChatVoiceStarted();
}

/// Descarta la grabación en curso sin enviarla.
final class TrainerChatVoiceCancelled extends TrainerChatEvent {
  const TrainerChatVoiceCancelled();
}

/// Envía la nota de voz grabada: corre el turno vía sendAudio (mismo manejo
/// que un mensaje de texto: sending/typing/SSE/cancel/fallos).
final class TrainerChatVoiceSent extends TrainerChatEvent {
  const TrainerChatVoiceSent(this.bytes, {this.filename = 'voice.ogg'});

  final Uint8List bytes;
  final String filename;
}

/// El composer cambió: persiste el borrador del hilo activo (sin re-emitir por
/// tecla; el borrador se siembra al cambiar de hilo).
final class TrainerChatDraftChanged extends TrainerChatEvent {
  const TrainerChatDraftChanged(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is TrainerChatDraftChanged && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// Progreso en vivo del turno recibido por SSE. Lo emite la suscripción
/// per-turn; el handler lo traduce a la etiqueta del indicador
/// ("Pensando…/Usando {tool}…"). Cosmético: nunca toca el contenido del hilo.
final class TrainerChatProgressReceived extends TrainerChatEvent {
  const TrainerChatProgressReceived(this.event);

  final TrainerProgressEvent event;
}

sealed class TrainerChatState {
  const TrainerChatState();
}

final class TrainerChatLoading extends TrainerChatState {
  const TrainerChatLoading();

  @override
  bool operator ==(Object other) => other is TrainerChatLoading;

  @override
  int get hashCode => (TrainerChatLoading).hashCode;
}

final class TrainerChatFailed extends TrainerChatState {
  const TrainerChatFailed(this.failure);

  final TrainerFailure failure;

  @override
  bool operator ==(Object other) =>
      other is TrainerChatFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

final class TrainerChatLoaded extends TrainerChatState {
  const TrainerChatLoaded({
    required this.conversation,
    required this.messages,
    required this.sending,
    this.conversations = const <TrainerConversation>[],
    this.liveProgress = '',
    this.sendFailure,
    this.models = const <TrainerModelOption>[],
    this.defaultModelId = '',
    this.selectedModelId = '',
    this.pendingAttachments = const <TrainerAttachment>[],
    this.pendingThumbnails = const <String, Uint8List>{},
    this.attaching = false,
    this.lastAttemptedContent = '',
    this.draft = '',
    this.recordingVoice = false,
  });

  final TrainerConversation conversation;

  /// Conversaciones del entrenamiento (DESC por updatedAt) para el selector de
  /// hilos. La activa es `conversation`.
  final List<TrainerConversation> conversations;

  /// Hilo en orden cronológico ASC (listo para render).
  final List<TrainerMessage> messages;

  /// true mientras el turno viaja (composer bloqueado + typing indicator).
  final bool sending;

  /// Etiqueta del indicador en vivo del turno ("Pensando…/Usando {tool}…"),
  /// alimentada por SSE. '' cuando no hay turno o el progreso aún no llega.
  final String liveProgress;

  /// Fallo del ÚLTIMO turno (el hilo sigue usable); null si no hubo.
  final TrainerFailure? sendFailure;

  /// Allowlist de modelos del entrenador (best-effort: vacía oculta el
  /// selector — backend sin la ruta o fallo de carga).
  final List<TrainerModelOption> models;

  /// Modelo default de la plataforma (informativo, para marcarlo en el menú).
  final String defaultModelId;

  /// Elección vigente del operador; '' = default (el turno viaja sin model).
  final String selectedModelId;

  /// Adjuntos YA subidos esperando el próximo send (chips en el composer).
  final List<TrainerAttachment> pendingAttachments;

  /// Bytes locales de los adjuntos-imagen pendientes, por ref: alimentan la
  /// miniatura del chip sin pedirla a la red. Solo viven para los pendientes
  /// (se descartan al enviar o quitar); NUNCA se persisten en drafts.
  final Map<String, Uint8List> pendingThumbnails;

  /// true mientras un adjunto sube (el clip muestra spinner).
  final bool attaching;

  /// Aviso de modalidad: si el modelo efectivo (elegido o, en su defecto, el
  /// default) declara NO ver imágenes/PDF y hay un pendiente de ese tipo,
  /// una línea honesta advierte que viajará como texto sustituto. Flags
  /// ausentes (wire viejo) ⇒ '' (degradación limpia, sin aviso).
  String get modalityWarning {
    if (pendingAttachments.isEmpty) return '';
    final effId = selectedModelId.isNotEmpty ? selectedModelId : defaultModelId;
    if (effId.isEmpty) return '';
    TrainerModelOption? opt;
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

  /// Texto del último turno enviado, conservado al fallar para que "Reintentar"
  /// lo re-despache y el composer lo recupere. '' si no hay nada que reintentar.
  final String lastAttemptedContent;

  /// Borrador del composer del hilo activo; se siembra al cambiar de hilo o al
  /// cancelar (la persistencia por-hilo vive en el bloc, en memoria).
  final String draft;

  /// true mientras se graba una nota de voz: reemplaza el composer por la barra
  /// de grabación y bloquea el envío de texto (una cosa a la vez).
  final bool recordingVoice;

  TrainerChatLoaded copyWith({
    TrainerConversation? conversation,
    List<TrainerConversation>? conversations,
    List<TrainerMessage>? messages,
    bool? sending,
    String? liveProgress,
    TrainerFailure? sendFailure,
    bool clearSendFailure = false,
    String? selectedModelId,
    List<TrainerAttachment>? pendingAttachments,
    Map<String, Uint8List>? pendingThumbnails,
    bool? attaching,
    String? lastAttemptedContent,
    String? draft,
    bool? recordingVoice,
  }) => TrainerChatLoaded(
    conversation: conversation ?? this.conversation,
    conversations: conversations ?? this.conversations,
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    liveProgress: liveProgress ?? this.liveProgress,
    sendFailure: clearSendFailure ? null : (sendFailure ?? this.sendFailure),
    models: models,
    defaultModelId: defaultModelId,
    selectedModelId: selectedModelId ?? this.selectedModelId,
    pendingAttachments: pendingAttachments ?? this.pendingAttachments,
    pendingThumbnails: pendingThumbnails ?? this.pendingThumbnails,
    attaching: attaching ?? this.attaching,
    lastAttemptedContent: lastAttemptedContent ?? this.lastAttemptedContent,
    draft: draft ?? this.draft,
    recordingVoice: recordingVoice ?? this.recordingVoice,
  );

  @override
  bool operator ==(Object other) =>
      other is TrainerChatLoaded &&
      other.conversation == conversation &&
      listEquals(other.conversations, conversations) &&
      listEquals(other.messages, messages) &&
      other.sending == sending &&
      other.liveProgress == liveProgress &&
      other.sendFailure == sendFailure &&
      listEquals(other.models, models) &&
      other.defaultModelId == defaultModelId &&
      other.selectedModelId == selectedModelId &&
      listEquals(other.pendingAttachments, pendingAttachments) &&
      mapEquals(other.pendingThumbnails, pendingThumbnails) &&
      other.attaching == attaching &&
      other.lastAttemptedContent == lastAttemptedContent &&
      other.draft == draft &&
      other.recordingVoice == recordingVoice;

  @override
  int get hashCode => Object.hash(
    conversation,
    Object.hashAll(conversations),
    Object.hashAll(messages),
    sending,
    liveProgress,
    sendFailure,
    Object.hashAll(models),
    defaultModelId,
    selectedModelId,
    Object.hashAll(pendingAttachments),
    Object.hashAll(pendingThumbnails.keys),
    attaching,
    lastAttemptedContent,
    draft,
    recordingVoice,
  );
}

class TrainerChatBloc extends Bloc<TrainerChatEvent, TrainerChatState> {
  TrainerChatBloc({
    required TrainerRepository repo,
    required String templateId,
    MediaFilePicker? picker,
    TrainerEvents? events,
    MediaByteSink? mediaSink,
  }) : _repo = repo,
       _templateId = templateId,
       _picker = picker,
       _events = events,
       _mediaSink = mediaSink,
       super(const TrainerChatLoading()) {
    on<TrainerChatStarted>(_onStarted);
    on<TrainerChatMessageSent>(_onMessageSent);
    on<TrainerChatAttachRequested>(_onAttachRequested);
    on<TrainerChatAttachmentRemoved>(_onAttachmentRemoved);
    on<TrainerChatNewConversationRequested>(_onNewConversation);
    on<TrainerChatConversationSelected>(_onConversationSelected);
    on<TrainerChatModelSelected>(_onModelSelected);
    on<TrainerChatProgressReceived>(_onProgressReceived);
    on<TrainerChatTurnCancelRequested>(_onTurnCancelRequested);
    on<TrainerChatDraftChanged>(_onDraftChanged);
    on<TrainerChatVoiceStarted>(_onVoiceStarted);
    on<TrainerChatVoiceCancelled>(_onVoiceCancelled);
    on<TrainerChatVoiceSent>(_onVoiceSent);
  }

  final TrainerRepository _repo;
  final String _templateId;

  /// Borradores del composer por conversationId (en memoria): sobreviven la
  /// destrucción del estado del composer al cerrar/reabrir la pantalla.
  final Map<String, String> _drafts = <String, String>{};

  /// true entre que el operador pide cancelar y que el POST abortado lanza:
  /// la guarda hace que el catch trague la excepción de cancelación en vez de
  /// pintarla como fallo real.
  bool _cancelRequested = false;

  /// Picker de archivos (nil ⇒ el composer oculta el clip — DX/tests).
  final MediaFilePicker? _picker;

  /// Caché local donde sembrar los bytes de un adjunto recién subido bajo su
  /// ref definitiva: el wire del entrenador no trae URL firmada, así que la
  /// burbuja enviada solo puede pintarse/reproducirse desde esta copia.
  /// nil ⇒ sin siembra (la burbuja degrada a la tarjeta con nombre).
  final MediaByteSink? _mediaSink;

  /// Realtime del turno (nil ⇒ sin indicador en vivo: el turno sigue funcionando
  /// con "Pensando…" estático). Best-effort, cosmético.
  final TrainerEvents? _events;

  /// Suscripción de progreso del turno en vuelo (per-turn): se abre al enviar y
  /// se cancela al volver el POST o al cerrarse el bloc.
  StreamSubscription<TrainerProgressEvent>? _progressSub;

  @override
  Future<void> close() {
    // Cancelar una suscripción SSE viva aguarda el desmonte del socket, que el
    // server mantiene abierto y puede no completar; el cierre del bloc no debe
    // colgarse en él.
    unawaited(_progressSub?.cancel());
    return super.close();
  }

  /// Allowlist de modelos, best-effort: el selector es accesorio — CUALQUIER
  /// fallo (backend sin la ruta, red, wire inesperado) lo oculta sin tocar
  /// la carga del hilo.
  Future<TrainerModels> _loadModels() async {
    try {
      return await _repo.listModels(templateId: _templateId);
    } on Object {
      return const TrainerModels(
        options: <TrainerModelOption>[],
        defaultId: '',
      );
    }
  }

  Future<List<TrainerMessage>> _loadMessages(String conversationId) async {
    final page = await _repo.listMessages(
      templateId: _templateId,
      conversationId: conversationId,
      limit: _pageLimit,
    );
    // El wire entrega DESC (recientes primero); el hilo renderiza ASC.
    return page.messages.reversed.toList(growable: false);
  }

  Future<void> _onStarted(
    TrainerChatStarted event,
    Emitter<TrainerChatState> emit,
  ) async {
    emit(const TrainerChatLoading());
    try {
      final convs = await _repo.listConversations(templateId: _templateId);
      final sorted = <TrainerConversation>[...convs]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final TrainerConversation conv;
      final List<TrainerConversation> list;
      if (sorted.isNotEmpty) {
        conv = sorted.first;
        list = sorted;
      } else {
        conv = await _repo.createConversation(
          templateId: _templateId,
          title: 'Entrenamiento',
        );
        list = <TrainerConversation>[conv];
      }
      final models = await _loadModels();
      emit(
        TrainerChatLoaded(
          conversation: conv,
          conversations: list,
          messages: await _loadMessages(conv.id),
          sending: false,
          models: models.options,
          defaultModelId: models.defaultId,
        ),
      );
    } on TrainerFailure catch (f) {
      emit(TrainerChatFailed(f));
    }
  }

  Future<void> _onMessageSent(
    TrainerChatMessageSent event,
    Emitter<TrainerChatState> emit,
  ) async {
    final current = state;
    // El envío se rechaza mientras un lote de adjuntos sube: capturar el estado
    // a mitad de subida enviaría un subconjunto y, al limpiar los pendientes con
    // ese estado stale, dejaría los archivos que aún subían huérfanos en storage
    // (perdidos sin aviso). El operador reenvía cuando la subida cierra.
    // Grabando una nota de voz tampoco se envía texto (una cosa a la vez).
    if (current is! TrainerChatLoaded ||
        current.sending ||
        current.attaching ||
        current.recordingVoice) {
      return;
    }
    _cancelRequested = false;
    _drafts.remove(current.conversation.id);
    final optimistic = TrainerMessage(
      id: 'optimistic',
      conversationId: current.conversation.id,
      role: 'user',
      content: event.content,
      attachments: current.pendingAttachments,
      createdAt: DateTime.now().toUtc(),
    );
    emit(
      current.copyWith(
        messages: <TrainerMessage>[...current.messages, optimistic],
        sending: true,
        liveProgress: 'Pensando…',
        clearSendFailure: true,
        lastAttemptedContent: event.content,
        draft: '',
      ),
    );
    // Indicador en vivo: suscripción de progreso per-turn. Best-effort —
    // cosmético; si no hay puerto de eventos o el SSE no conecta, el indicador
    // se queda en "Pensando…". El cancel NO se espera: cancelar una suscripción
    // SSE viva aguarda el desmonte del socket (que el server mantiene abierto) y
    // puede no completar — esperarlo colgaría el cierre del turno en "Pensando…".
    unawaited(_progressSub?.cancel());
    _progressSub = _events
        ?.progress(_templateId, current.conversation.id)
        .listen((e) {
          if (!isClosed) add(TrainerChatProgressReceived(e));
        }, onError: (Object _) {});
    try {
      await _repo.sendMessage(
        templateId: _templateId,
        conversationId: current.conversation.id,
        content: event.content,
        model: current.selectedModelId.isEmpty ? null : current.selectedModelId,
        attachments: current.pendingAttachments
            .map((a) => a.ref)
            .toList(growable: false),
      );
      unawaited(_progressSub?.cancel());
      _progressSub = null;
      // El POST (200) YA persistió el turno: cerramos de INMEDIATO (sending=false)
      // para que "Detener" no siga vivo durante la recarga —si se tocara ahí,
      // revertiría un turno ya guardado y dejaría su texto en el composer. El
      // optimista mantiene visible el mensaje enviado hasta que llega el hilo.
      emit(
        current.copyWith(
          messages: <TrainerMessage>[...current.messages, optimistic],
          sending: false,
          liveProgress: '',
          clearSendFailure: true,
          pendingAttachments: const <TrainerAttachment>[],
          pendingThumbnails: const <String, Uint8List>{},
          lastAttemptedContent: '',
        ),
      );
      // Recarga best-effort (turno ya cerrado): trae el hilo real del server,
      // incl. la respuesta y los tool results que el POST no devuelve.
      await _reloadThread(emit, current.conversation.id);
    } on TrainerFailure catch (f) {
      unawaited(_progressSub?.cancel());
      _progressSub = null;
      // El turno se canceló: el handler de cancelación ya dejó el estado limpio.
      // Tragamos la excepción del POST abortado en vez de pintarla como fallo.
      if (_cancelRequested) {
        _cancelRequested = false;
        return;
      }
      // Revertir el optimista: el server no persistió el turno (502 del motor
      // deja el user message fuera del hilo — reintentable). `current` conserva
      // los adjuntos pendientes y guardamos el texto para "Reintentar".
      emit(
        current.copyWith(
          sending: false,
          liveProgress: '',
          sendFailure: f,
          lastAttemptedContent: event.content,
        ),
      );
    }
  }

  /// Recarga el hilo tras cerrar un turno (se llama DESPUÉS de emitir
  /// sending=false). Best-effort y no bloqueante del cierre: si falla, el
  /// optimista ya deja visible el mensaje enviado; si el operador cambió de hilo
  /// o arrancó otro envío, no se aplica —nunca pisa un hilo que ya tiene abierto.
  Future<void> _reloadThread(
    Emitter<TrainerChatState> emit,
    String conversationId,
  ) async {
    List<TrainerMessage> reloaded;
    try {
      reloaded = await _loadMessages(conversationId);
    } on TrainerFailure {
      return;
    }
    if (isClosed) return;
    final s = state;
    if (s is! TrainerChatLoaded ||
        s.conversation.id != conversationId ||
        s.sending) {
      return;
    }
    emit(s.copyWith(messages: reloaded));
  }

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

  Future<void> _onAttachRequested(
    TrainerChatAttachRequested event,
    Emitter<TrainerChatState> emit,
  ) async {
    final current = state;
    final picker = _picker;
    if (current is! TrainerChatLoaded || picker == null || current.attaching) {
      return;
    }
    final picked = await picker.pickMultiple();
    if (picked.isEmpty) return; // canceló o nada con bytes.
    final afterPick = state;
    if (afterPick is! TrainerChatLoaded) return;

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
              ? const TrainerAttachmentUnsupportedFailure()
              : anyTooLarge
              ? const TrainerAttachmentTooLargeFailure()
              : const TrainerAttachmentLimitFailure(),
        ),
      );
      return;
    }

    emit(afterPick.copyWith(attaching: true, clearSendFailure: true));
    for (final p in toUpload) {
      try {
        final att = await _repo.uploadAttachment(
          templateId: _templateId,
          bytes: p.bytes,
          filename: p.filename,
        );
        // Siembra la copia local bajo la ref definitiva: la burbuja del turno
        // enviado se pinta/reproduce desde caché (el wire no trae URL firmada).
        // Best-effort y no bloqueante de la subida del lote.
        final sink = _mediaSink;
        if (sink != null) unawaited(sink.cache(att.ref, p.bytes));
        final cur = state;
        if (cur is! TrainerChatLoaded) return;
        // La miniatura local solo aplica a imágenes; el resto usa ícono.
        final thumbs = att.mime.startsWith('image/')
            ? <String, Uint8List>{...cur.pendingThumbnails, att.ref: p.bytes}
            : null;
        emit(
          cur.copyWith(
            pendingAttachments: <TrainerAttachment>[
              ...cur.pendingAttachments,
              att,
            ],
            pendingThumbnails: thumbs,
          ),
        );
      } on TrainerFailure catch (f) {
        final cur = state;
        if (cur is! TrainerChatLoaded) return;
        // Corta el lote en la primera falla de red/servidor y la muestra.
        emit(cur.copyWith(attaching: false, sendFailure: f));
        return;
      }
    }

    final cur = state;
    if (cur is! TrainerChatLoaded) return;
    // Cierre del lote: si algo se descartó client-side, informarlo (tipo >
    // peso > cupo); si todo entró, limpiar cualquier aviso previo.
    final notice = anyUnsupported
        ? const TrainerAttachmentUnsupportedFailure()
        : anyTooLarge
        ? const TrainerAttachmentTooLargeFailure()
        : (anyOverLimit ? const TrainerAttachmentLimitFailure() : null);
    emit(
      cur.copyWith(
        attaching: false,
        sendFailure: notice,
        clearSendFailure: notice == null,
      ),
    );
  }

  void _onAttachmentRemoved(
    TrainerChatAttachmentRemoved event,
    Emitter<TrainerChatState> emit,
  ) {
    final current = state;
    if (current is! TrainerChatLoaded) return;
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

  void _onModelSelected(
    TrainerChatModelSelected event,
    Emitter<TrainerChatState> emit,
  ) {
    final current = state;
    if (current is! TrainerChatLoaded) return;
    emit(current.copyWith(selectedModelId: event.modelId));
  }

  void _onTurnCancelRequested(
    TrainerChatTurnCancelRequested event,
    Emitter<TrainerChatState> emit,
  ) {
    final current = state;
    if (current is! TrainerChatLoaded || !current.sending) return;
    _cancelRequested = true;
    _repo.cancelSend();
    unawaited(_progressSub?.cancel());
    _progressSub = null;
    // Devolver el texto cancelado al borrador para que el operador lo reedite;
    // los adjuntos pendientes se conservan (current.copyWith no los toca).
    final cancelled = current.lastAttemptedContent;
    if (cancelled.isNotEmpty) {
      _drafts[current.conversation.id] = cancelled;
    }
    emit(
      current.copyWith(
        messages: current.messages
            .where((m) => m.id != 'optimistic')
            .toList(growable: false),
        sending: false,
        liveProgress: '',
        clearSendFailure: true,
        draft: cancelled,
      ),
    );
  }

  void _onVoiceStarted(
    TrainerChatVoiceStarted event,
    Emitter<TrainerChatState> emit,
  ) {
    final current = state;
    // No arrancar sobre un turno en vuelo, una subida de adjuntos, ni una
    // grabación ya activa (una cosa a la vez).
    if (current is! TrainerChatLoaded ||
        current.sending ||
        current.attaching ||
        current.recordingVoice) {
      return;
    }
    emit(current.copyWith(recordingVoice: true, clearSendFailure: true));
  }

  void _onVoiceCancelled(
    TrainerChatVoiceCancelled event,
    Emitter<TrainerChatState> emit,
  ) {
    final current = state;
    if (current is! TrainerChatLoaded || !current.recordingVoice) return;
    emit(current.copyWith(recordingVoice: false));
  }

  /// Corre el turno de una nota de voz: sube el clip vía sendAudio y cierra con
  /// el assistant final, reusando la máquina del turno de texto (sending/typing/
  /// SSE/recarga). No hay burbuja optimista del user (el audio aún no tiene ref;
  /// el user con su transcript llega en la recarga) ni reintento (el clip ya no
  /// está en mano tras enviarlo).
  Future<void> _onVoiceSent(
    TrainerChatVoiceSent event,
    Emitter<TrainerChatState> emit,
  ) async {
    final current = state;
    // Sin grabación en curso no hay clip que enviar: un VoiceSent espurio (sin
    // el VoiceStarted previo) no debe correr un turno de audio. Espeja la guarda
    // de _onVoiceStarted (que ignora arrancar sobre una grabación ya activa).
    if (current is! TrainerChatLoaded ||
        current.sending ||
        current.attaching ||
        !current.recordingVoice) {
      return;
    }
    final convId = current.conversation.id;
    _cancelRequested = false;
    emit(
      current.copyWith(
        recordingVoice: false,
        sending: true,
        liveProgress: 'Pensando…',
        clearSendFailure: true,
        lastAttemptedContent: '',
      ),
    );
    unawaited(_progressSub?.cancel());
    _progressSub = _events?.progress(_templateId, convId).listen((e) {
      if (!isClosed) add(TrainerChatProgressReceived(e));
    }, onError: (Object _) {});
    try {
      final assistant = await _repo.sendAudio(
        templateId: _templateId,
        conversationId: convId,
        bytes: event.bytes,
        filename: event.filename,
      );
      unawaited(_progressSub?.cancel());
      _progressSub = null;
      emit(
        current.copyWith(
          messages: <TrainerMessage>[...current.messages, assistant],
          recordingVoice: false,
          sending: false,
          liveProgress: '',
          clearSendFailure: true,
        ),
      );
      // Recarga best-effort: trae el user de voz (con su transcript) y los
      // tool results que el POST no devuelve.
      await _reloadThread(emit, convId);
      _seedVoiceBytes(event.bytes);
    } on TrainerFailure catch (f) {
      unawaited(_progressSub?.cancel());
      _progressSub = null;
      // El turno se canceló: el handler de cancelación ya dejó el estado limpio.
      if (_cancelRequested) {
        _cancelRequested = false;
        return;
      }
      emit(
        current.copyWith(
          recordingVoice: false,
          sending: false,
          liveProgress: '',
          sendFailure: f,
        ),
      );
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
    if (sink == null || s is! TrainerChatLoaded) return;
    for (final m in s.messages.reversed) {
      if (m.isUser && m.audioRef.isNotEmpty) {
        unawaited(sink.cache(m.audioRef, bytes));
        return;
      }
    }
  }

  void _onDraftChanged(
    TrainerChatDraftChanged event,
    Emitter<TrainerChatState> emit,
  ) {
    final current = state;
    if (current is! TrainerChatLoaded) return;
    // Persistir sin re-emitir: el composer es la fuente de verdad mientras el
    // hilo está abierto; el borrador se siembra al cambiar de hilo o cancelar.
    _drafts[current.conversation.id] = event.text;
  }

  Future<void> _onConversationSelected(
    TrainerChatConversationSelected event,
    Emitter<TrainerChatState> emit,
  ) async {
    final current = state;
    if (current is! TrainerChatLoaded || current.sending) return;
    if (event.id == current.conversation.id) return; // ya activa
    TrainerConversation? target;
    for (final c in current.conversations) {
      if (c.id == event.id) {
        target = c;
        break;
      }
    }
    if (target == null) return;
    try {
      emit(
        current.copyWith(
          conversation: target,
          messages: await _loadMessages(target.id),
          clearSendFailure: true,
          draft: _drafts[target.id] ?? '',
        ),
      );
    } on TrainerFailure catch (f) {
      emit(current.copyWith(sendFailure: f));
    }
  }

  void _onProgressReceived(
    TrainerChatProgressReceived event,
    Emitter<TrainerChatState> emit,
  ) {
    final current = state;
    if (current is! TrainerChatLoaded || !current.sending) return;
    if (event.event.conversationId != current.conversation.id) return;
    final label = _progressLabel(event.event);
    if (label.isEmpty || label == current.liveProgress) return;
    emit(current.copyWith(liveProgress: label));
  }

  String _progressLabel(TrainerProgressEvent e) {
    if (e.isTool) {
      return e.toolName.isNotEmpty ? 'Usando ${e.toolName}…' : 'Trabajando…';
    }
    if (e.isThinking) return 'Pensando…';
    return ''; // terminal: el cierre del POST limpia el indicador.
  }

  Future<void> _onNewConversation(
    TrainerChatNewConversationRequested event,
    Emitter<TrainerChatState> emit,
  ) async {
    // La allowlist de modelos y la elección del operador son de la pantalla
    // (template/servidor), no de la conversación: deben sobrevivir al iniciar
    // un hilo nuevo, o el selector de modelo desaparecería. Se heredan del
    // estado cargado vivo; si no lo había (nueva conversación lanzada desde
    // Loading/Failed), se recargan best-effort.
    final preserved = state is TrainerChatLoaded
        ? state as TrainerChatLoaded
        : null;
    emit(const TrainerChatLoading());
    try {
      final conv = await _repo.createConversation(
        templateId: _templateId,
        title: 'Entrenamiento',
      );
      final models = preserved != null
          ? TrainerModels(
              options: preserved.models,
              defaultId: preserved.defaultModelId,
            )
          : await _loadModels();
      emit(
        TrainerChatLoaded(
          conversation: conv,
          conversations: <TrainerConversation>[
            conv,
            ...?preserved?.conversations,
          ],
          messages: const <TrainerMessage>[],
          sending: false,
          models: models.options,
          defaultModelId: models.defaultId,
          selectedModelId: preserved?.selectedModelId ?? '',
        ),
      );
    } on TrainerFailure catch (f) {
      emit(TrainerChatFailed(f));
    }
  }
}
