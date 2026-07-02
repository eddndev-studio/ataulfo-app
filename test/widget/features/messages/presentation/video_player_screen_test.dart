import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/messages/presentation/widgets/video_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El plugin de video no está registrado en el entorno de test: la
/// inicialización falla y la pantalla debe degradar (estado de error) sin
/// romper, conservando el botón de cerrar. La reproducción real es E2E.
void main() {
  testWidgets('construye y degrada sin romper (sin plugin) conservando cerrar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: const VideoPlayerScreen(url: 'https://cdn/x.mp4'),
      ),
    );
    // Un pump procesa el fallo de init (MissingPluginException) → estado error.
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('video_player.close')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
