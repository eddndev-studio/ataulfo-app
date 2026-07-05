import 'package:ataulfo/features/media/data/repositories/noop_camera_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isSupported siempre responde false', () async {
    const capture = NoopCameraCapture();
    expect(await capture.isSupported(), isFalse);
  });

  test('takePhoto/takeVideo son seguros: resuelven null sin lanzar', () async {
    const capture = NoopCameraCapture();
    expect(await capture.takePhoto(), isNull);
    expect(await capture.takeVideo(), isNull);
  });
}
