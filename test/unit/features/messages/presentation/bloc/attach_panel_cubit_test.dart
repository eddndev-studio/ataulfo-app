import 'package:ataulfo/features/media/domain/repositories/device_gallery_port.dart';
import 'package:ataulfo/features/messages/presentation/bloc/attach_panel_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estado de apertura/vista', () {
    test('estado inicial es null (panel cerrado)', () {
      final cubit = AttachPanelCubit();
      addTearDown(cubit.close);
      expect(cubit.state, isNull);
      expect(cubit.isOpen, isFalse);
    });

    test('open abre en la vista de destinos con los flags de soporte', () {
      final cubit = AttachPanelCubit();
      addTearDown(cubit.close);
      cubit.open(showCamera: true, showGallery: false);
      expect(cubit.isOpen, isTrue);
      expect(cubit.state?.view, AttachPanelView.destinations);
      expect(cubit.state?.showCamera, isTrue);
      expect(cubit.state?.showGallery, isFalse);
    });

    test(
      'showCameraView cambia a la vista de cámara conservando los flags',
      () {
        final cubit = AttachPanelCubit();
        addTearDown(cubit.close);
        cubit.open(showCamera: true, showGallery: true);
        cubit.showCameraView();
        expect(cubit.state?.view, AttachPanelView.camera);
        expect(cubit.state?.showCamera, isTrue);
        expect(cubit.state?.showGallery, isTrue);
      },
    );

    test('showDestinations vuelve a la vista de destinos', () {
      final cubit = AttachPanelCubit();
      addTearDown(cubit.close);
      cubit.open(showCamera: true, showGallery: true);
      cubit.showCameraView();
      cubit.showDestinations();
      expect(cubit.state?.view, AttachPanelView.destinations);
    });

    test('showCameraView/showDestinations son no-op con el panel cerrado', () {
      final cubit = AttachPanelCubit();
      addTearDown(cubit.close);
      cubit.showCameraView();
      expect(cubit.state, isNull);
      cubit.showDestinations();
      expect(cubit.state, isNull);
    });

    test('dismiss cierra el panel', () {
      final cubit = AttachPanelCubit();
      addTearDown(cubit.close);
      cubit.open(showCamera: false, showGallery: false);
      cubit.dismiss();
      expect(cubit.state, isNull);
    });
  });

  group('intenciones (canal aparte, cierran el panel al elegir)', () {
    test('chooseDocument publica AttachDocumentIntent y cierra', () async {
      final cubit = AttachPanelCubit();
      addTearDown(cubit.close);
      cubit.open(showCamera: false, showGallery: false);
      final intents = <AttachIntent>[];
      final sub = cubit.intents.listen(intents.add);
      addTearDown(sub.cancel);

      cubit.chooseDocument();
      await Future<void>.delayed(Duration.zero);

      expect(intents.single, isA<AttachDocumentIntent>());
      expect(cubit.state, isNull);
    });

    test('chooseMedia publica AttachMediaIntent', () async {
      final cubit = AttachPanelCubit();
      addTearDown(cubit.close);
      cubit.open(showCamera: false, showGallery: false);
      final intents = <AttachIntent>[];
      final sub = cubit.intents.listen(intents.add);
      addTearDown(sub.cancel);

      cubit.chooseMedia();
      await Future<void>.delayed(Duration.zero);

      expect(intents.single, isA<AttachMediaIntent>());
      expect(cubit.state, isNull);
    });

    test(
      'choosePhoto/chooseVideo publican sus intenciones de cámara',
      () async {
        final cubit = AttachPanelCubit();
        addTearDown(cubit.close);
        cubit.open(showCamera: true, showGallery: false);
        final intents = <AttachIntent>[];
        final sub = cubit.intents.listen(intents.add);
        addTearDown(sub.cancel);

        cubit.choosePhoto();
        cubit.open(showCamera: true, showGallery: false);
        cubit.chooseVideo();
        await Future<void>.delayed(Duration.zero);

        expect(intents, <Matcher>[
          isA<AttachPhotoIntent>(),
          isA<AttachVideoIntent>(),
        ]);
      },
    );

    test(
      'confirmGallery publica AttachGalleryIntent con los assets y cierra',
      () async {
        final cubit = AttachPanelCubit();
        addTearDown(cubit.close);
        cubit.open(showCamera: false, showGallery: true);
        final intents = <AttachIntent>[];
        final sub = cubit.intents.listen(intents.add);
        addTearDown(sub.cancel);

        const assets = <DeviceMediaAsset>[
          DeviceMediaAsset(id: 'a1', filename: 'uno.jpg'),
          DeviceMediaAsset(id: 'a2', filename: 'dos.png'),
        ];
        cubit.confirmGallery(assets);
        await Future<void>.delayed(Duration.zero);

        final intent = intents.single;
        expect(intent, isA<AttachGalleryIntent>());
        expect((intent as AttachGalleryIntent).assets, assets);
        expect(cubit.state, isNull);
      },
    );
  });
}
