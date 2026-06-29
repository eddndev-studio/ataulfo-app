import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El AndroidManifest.xml del flavor `main` debe declarar
/// `android.permission.INTERNET`. Es la única defensa contra builds release
/// rotos por silencio: el flavor `debug` lo declara aparte para el tooling
/// de Flutter (hot reload, attach del observador), así que un repo recién
/// generado con `flutter create` puede pasar todos los smokes que corren
/// en debug y aterrizar al device en release sin un solo socket abierto.
/// El cliente lo manifiesta como "Sin conexión, reintenta" eterno — no hay
/// crash ni exception en logs, sólo fallos en DioException nivel network.
void main() {
  test('main AndroidManifest declara android.permission.INTERNET', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android.permission.INTERNET'),
      reason:
          'El merge del release sólo combina main + release/AndroidManifest. '
          'Sin esta permission en main, el APK release no puede abrir sockets.',
    );
  });

  test('main AndroidManifest declara android.permission.RECORD_AUDIO', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android.permission.RECORD_AUDIO'),
      reason:
          'Sin RECORD_AUDIO en el manifest del flavor main, la grabación de '
          'notas de voz no puede acceder al micrófono en el APK release.',
    );
  });
}
