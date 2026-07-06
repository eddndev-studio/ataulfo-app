import 'dart:convert';
import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';
import 'package:ataulfo/features/messages/presentation/widgets/media_viewer.dart';
import 'package:ataulfo/features/messages/presentation/widgets/video_playback.dart';
import 'package:ataulfo/features/messages/presentation/widgets/video_player_screen.dart';
import 'package:ataulfo/features/messages/presentation/widgets/viewer_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// PNG gris de 300×300: lo bastante grande para que "tocar la foto" sea un
/// gesto real (un PNG de 1px se pintaría como un punto imposible de tocar).
final _pngBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAASwAAAEsCAIAAAD2HxkiAAADUklEQVR4nO3TMQEAAAiAMKMb3Rgcbgl4mAVSUwfAdyaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIWZCiJkQYiaEmAkhZkKImRBiJoSYCSFmQoiZEGImhJgJIXYycHbi70aCGAAAAABJRU5ErkJggg==',
  ),
);

Widget _host({required void Function(BuildContext) onTap}) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const Key('host.open'),
          onPressed: () => onTap(context),
          child: const Text('abrir'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('tocar la FOTO no cierra el visor; tocar el fondo sí', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(onTap: (context) => showMediaViewer(context, bytes: _pngBytes)),
    );
    // Precachea los bytes: el decode de MemoryImage es asíncrono real y
    // pumpAndSettle (tiempo falso) no lo espera; sin tamaño, la foto no
    // ocuparía área tocable.
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(_pngBytes),
        tester.element(find.byKey(const Key('host.open'))),
      ),
    );
    await tester.tap(find.byKey(const Key('host.open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('media_viewer')), findsOneWidget);

    // Un tap sobre la imagen (centro de pantalla) NO debe cerrar: tras hacer
    // zoom, un toque perdido no puede tirar el visor.
    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('media_viewer')), findsOneWidget);

    // Un tap en el fondo (fuera de la imagen) cierra.
    await tester.tapAt(const Offset(8, 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('media_viewer')), findsNothing);
  });

  testWidgets('imagen por URL que falla ofrece Reintentar (AppErrorState)', (
    tester,
  ) async {
    // En el entorno de test toda petición HTTP responde 400: Image.network
    // cae al errorBuilder de inmediato.
    await tester.pumpWidget(
      _host(
        onTap: (context) => showMediaViewer(context, url: 'https://cdn/x.jpg'),
      ),
    );
    await tester.tap(find.byKey(const Key('host.open')));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    // Reintentar re-dispara la carga (vuelve a fallar aquí) sin tirar el visor.
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('media_viewer')), findsOneWidget);
    expect(find.byType(AppErrorState), findsOneWidget);
  });

  testWidgets(
    'el reproductor de video comparte el shell del visor (cierre + fondo)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: const VideoPlayerScreen(url: 'https://cdn/x.mp4'),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(ViewerShell), findsOneWidget);
      expect(find.byKey(const Key('video_player.close')), findsOneWidget);
    },
  );

  testWidgets(
    'InAppVideoPlayback abre una ruta transparente: el hilo sigue visible',
    (tester) async {
      await tester.pumpWidget(
        _host(
          onTap: (context) => const InAppVideoPlayback().open(
            context,
            url: 'https://cdn/x.mp4',
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('host.open')));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ViewerShell), findsOneWidget);
      // Ruta transparente (mismo patrón que el visor de imagen): lo de abajo
      // no se desmonta del árbol visible.
      expect(find.text('abrir'), findsOneWidget);
    },
  );
}
