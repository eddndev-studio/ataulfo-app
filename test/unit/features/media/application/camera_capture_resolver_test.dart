import 'package:ataulfo/features/media/application/camera_capture_resolver.dart';
import 'package:ataulfo/features/media/data/repositories/noop_camera_capture.dart';
import 'package:ataulfo/features/media/domain/repositories/camera_capture.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cámara de prueba: marca que la factory de Android se invocó sin construir
/// el plugin real (que necesitaría canales de plataforma).
class _StubCapture implements CameraCapture {
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<PickedMedia?> takePhoto() async => null;
  @override
  Future<PickedMedia?> takeVideo() async => null;
}

void main() {
  test('en Android construye la cámara real (factory inyectada)', () {
    var built = 0;
    final resolver = CameraCaptureResolver(
      isAndroid: true,
      androidCapture: () {
        built++;
        return _StubCapture();
      },
    );

    final c = resolver.resolve();

    expect(built, 1);
    expect(c, isA<_StubCapture>());
  });

  test('fuera de Android usa el Noop (sin construir el real)', () {
    var built = 0;
    final resolver = CameraCaptureResolver(
      isAndroid: false,
      androidCapture: () {
        built++;
        return _StubCapture();
      },
    );

    final c = resolver.resolve();

    expect(built, 0);
    expect(c, isA<NoopCameraCapture>());
  });
}
