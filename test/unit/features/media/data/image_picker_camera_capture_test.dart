import 'package:ataulfo/features/media/data/repositories/image_picker_camera_capture.dart';
import 'package:ataulfo/features/media/domain/repositories/camera_capture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockImagePicker extends Mock implements ImagePicker {}

void main() {
  setUpAll(() {
    registerFallbackValue(ImageSource.camera);
  });

  group('pickedFromXFile (mapeo puro)', () {
    test('null (captura cancelada) mapea a null', () async {
      expect(await pickedFromXFile(null), isNull);
    });

    test('XFile mapea a PickedMedia con bytes y basename del path', () async {
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);
      // En io, `XFile.name` SIEMPRE es el basename del path (el parámetro
      // `name` se ignora); `fromData` sirve los bytes desde memoria.
      final file = XFile.fromData(bytes, path: '/tmp/captura/foto.jpg');

      final picked = await pickedFromXFile(file);

      expect(picked, isNotNull);
      expect(picked!.bytes, bytes);
      expect(picked.filename, 'foto.jpg');
    });
  });

  group('ImagePickerCameraCapture', () {
    late _MockImagePicker picker;
    late ImagePickerCameraCapture capture;

    setUp(() {
      picker = _MockImagePicker();
      capture = ImagePickerCameraCapture(picker: picker);
    });

    test('isSupported responde true (el gate real es el resolver)', () async {
      expect(await capture.isSupported(), isTrue);
    });

    test('takePhoto abre la cámara de fotos y mapea el resultado', () async {
      final bytes = Uint8List.fromList(<int>[9, 8]);
      when(
        () => picker.pickImage(source: ImageSource.camera),
      ).thenAnswer((_) async => XFile.fromData(bytes, path: '/tmp/f.jpg'));

      final picked = await capture.takePhoto();

      expect(picked!.bytes, bytes);
      expect(picked.filename, 'f.jpg');
      verifyNever(() => picker.pickVideo(source: any(named: 'source')));
    });

    test('takeVideo abre la cámara de video y mapea el resultado', () async {
      final bytes = Uint8List.fromList(<int>[7]);
      when(
        () => picker.pickVideo(source: ImageSource.camera),
      ).thenAnswer((_) async => XFile.fromData(bytes, path: '/tmp/v.mp4'));

      final picked = await capture.takeVideo();

      expect(picked!.bytes, bytes);
      expect(picked.filename, 'v.mp4');
      verifyNever(() => picker.pickImage(source: any(named: 'source')));
    });

    test('cancelar la captura (XFile null) resuelve null', () async {
      when(
        () => picker.pickImage(source: ImageSource.camera),
      ).thenAnswer((_) async => null);
      when(
        () => picker.pickVideo(source: ImageSource.camera),
      ).thenAnswer((_) async => null);

      expect(await capture.takePhoto(), isNull);
      expect(await capture.takeVideo(), isNull);
    });

    test('un fallo del plugin en foto degrada a CameraCaptureFailure (nunca la '
        'excepción cruda de plataforma)', () async {
      when(
        () => picker.pickImage(source: ImageSource.camera),
      ).thenThrow(PlatformException(code: 'already_active'));

      expect(capture.takePhoto(), throwsA(isA<CameraCaptureFailure>()));
    });

    test(
      'un fallo del plugin en video degrada a CameraCaptureFailure',
      () async {
        when(
          () => picker.pickVideo(source: ImageSource.camera),
        ).thenThrow(PlatformException(code: 'camera_access_denied'));

        expect(capture.takeVideo(), throwsA(isA<CameraCaptureFailure>()));
      },
    );
  });
}
