import 'dart:typed_data';

import 'package:ataulfo/core/audio/audio_recorder.dart';
import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/repositories/camera_capture.dart';
import 'package:ataulfo/features/media/domain/repositories/device_gallery_port.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/messages/data/media/noop_audio_recorder.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:ataulfo/features/messages/presentation/bloc/reply_draft_cubit.dart';
import 'package:ataulfo/features/messages/presentation/widgets/message_composer.dart';
import 'package:ataulfo/features/quick_replies/presentation/bloc/quick_replies_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMessagesBloc extends MockBloc<MessagesEvent, MessagesState>
    implements MessagesBloc {}

class _MockQuickRepliesBloc
    extends MockBloc<QuickRepliesEvent, QuickRepliesState>
    implements QuickRepliesBloc {}

class _MockFilePicker extends Mock implements MediaFilePicker {}

class _MockMediaRepo extends Mock implements MediaRepository {}

class _MockCamera extends Mock implements CameraCapture {}

/// Carrete falso: assets fijos y bytes por id; los ids en [unreadable] simulan
/// un asset borrado entre la selección y la lectura (bytesFor → null).
class _FakeGallery implements DeviceGalleryPort {
  _FakeGallery({
    required this.supported,
    this.assets = const <DeviceMediaAsset>[],
    this.unreadable = const <String>{},
  });

  final bool supported;
  final List<DeviceMediaAsset> assets;
  final Set<String> unreadable;
  int bytesForCalls = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<List<DeviceMediaAsset>> recentMedia({int limit = 60}) async =>
      assets.take(limit).toList(growable: false);

  @override
  Future<Uint8List?> thumbnailFor(DeviceMediaAsset asset, {int size = 256}) =>
      Future<Uint8List?>.value();

  @override
  Future<PickedMedia?> bytesFor(DeviceMediaAsset asset) async {
    bytesForCalls++;
    if (unreadable.contains(asset.id)) return null;
    return PickedMedia(
      bytes: Uint8List.fromList(<int>[7, 7]),
      filename: asset.filename,
    );
  }
}

const List<DeviceMediaAsset> _assets = <DeviceMediaAsset>[
  DeviceMediaAsset(id: 'a1', filename: 'uno.jpg'),
  DeviceMediaAsset(id: 'a2', filename: 'dos.mp4', isVideo: true),
  DeviceMediaAsset(id: 'a3', filename: 'tres.png'),
];

void main() {
  late _MockMessagesBloc msgBloc;
  late _MockQuickRepliesBloc qrBloc;
  late _MockFilePicker picker;
  late _MockMediaRepo mediaRepo;
  late _MockCamera camera;

  setUp(() {
    msgBloc = _MockMessagesBloc();
    qrBloc = _MockQuickRepliesBloc();
    picker = _MockFilePicker();
    mediaRepo = _MockMediaRepo();
    camera = _MockCamera();
    when(() => msgBloc.state).thenReturn(
      const MessagesLoaded(
        items: <Message>[],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
    when(() => qrBloc.state).thenReturn(const QuickRepliesLoading());
    when(camera.isSupported).thenAnswer((_) async => false);
  });

  Widget host(DeviceGalleryPort gallery) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<MediaFilePicker>.value(value: picker),
        RepositoryProvider<MediaRepository>.value(value: mediaRepo),
        RepositoryProvider<CameraCapture>.value(value: camera),
        RepositoryProvider<DeviceGalleryPort>.value(value: gallery),
        RepositoryProvider<AudioRecorder>.value(
          value: const NoopAudioRecorder(),
        ),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<MessagesBloc>.value(value: msgBloc),
          BlocProvider<QuickRepliesBloc>.value(value: qrBloc),
          BlocProvider<ReplyDraftCubit>(create: (_) => ReplyDraftCubit()),
        ],
        child: const Scaffold(body: MessageComposer()),
      ),
    ),
  );

  Future<void> pumpPhone(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
  }

  Future<void> openAttachMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('composer.attach')));
    await tester.pumpAndSettle();
  }

  testWidgets('sin soporte de carrete el menú NO ofrece Galería ni grilla', (
    tester,
  ) async {
    await pumpPhone(tester, host(_FakeGallery(supported: false)));
    await openAttachMenu(tester);

    expect(find.byKey(const Key('attach_menu_sheet')), findsOneWidget);
    expect(find.byKey(const Key('attach_menu.gallery')), findsNothing);
    expect(find.byKey(const Key('attach_gallery.grid')), findsNothing);
  });

  testWidgets('con soporte, el menú abre con la grilla de recientes embebida', (
    tester,
  ) async {
    await pumpPhone(
      tester,
      host(_FakeGallery(supported: true, assets: _assets)),
    );
    await openAttachMenu(tester);

    // Sin taps adicionales: íconos arriba y carrete debajo.
    expect(find.byKey(const Key('attach_menu.gallery')), findsOneWidget);
    expect(find.byKey(const Key('attach_gallery.grid')), findsOneWidget);
    expect(find.byKey(const Key('attach_gallery.item.a1')), findsOneWidget);
  });

  testWidgets('Adjuntar (2) agrega exactamente 2 adjuntos a la bandeja', (
    tester,
  ) async {
    final gallery = _FakeGallery(supported: true, assets: _assets);
    await pumpPhone(tester, host(gallery));
    await openAttachMenu(tester);

    await tester.tap(find.byKey(const Key('attach_gallery.item.a1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach_gallery.item.a2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach_gallery.confirm')));
    await tester.pumpAndSettle();

    // El sheet cerró; los bytes se pidieron bajo demanda (uno por asset) y la
    // bandeja tiene los 2 adjuntos: el video muestra nombre+ícono de video.
    expect(find.byKey(const Key('attach_gallery.grid')), findsNothing);
    expect(gallery.bytesForCalls, 2);
    expect(find.byKey(const Key('composer.attachment_tray')), findsOneWidget);
    expect(find.text('2 archivos'), findsOneWidget);
    expect(find.text('dos.mp4'), findsOneWidget);
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
  });

  testWidgets('un asset ilegible se omite del lote con aviso', (tester) async {
    final gallery = _FakeGallery(
      supported: true,
      assets: _assets,
      unreadable: <String>{'a1'},
    );
    await pumpPhone(tester, host(gallery));
    await openAttachMenu(tester);

    await tester.tap(find.byKey(const Key('attach_gallery.item.a1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach_gallery.item.a3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach_gallery.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('1 archivo'), findsOneWidget);
    expect(
      find.text('1 archivo del carrete ya no está disponible'),
      findsOneWidget,
    );
  });
}
