import 'dart:async';
import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/data/cache/media_thumbnail_loader.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/presentation/widgets/media_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loader fake: devuelve un futuro fijo, sin tocar disco ni red.
class _FakeLoader implements MediaThumbnailLoader {
  _FakeLoader(this._result);
  final Future<Uint8List?> _result;
  @override
  Future<Uint8List?> load(MediaAsset asset) => _result;
}

// PNG 1x1 transparente válido — bytes reales para que el camino de imagen no
// caiga al errorBuilder por datos corruptos.
final _png1x1 = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

MediaAsset _asset({
  String contentType = 'image/png',
  String filename = 'foto.png',
}) => MediaAsset(
  ref: 'tenant/o/media/x',
  previewUrl: 'https://x/sig',
  filename: filename,
  contentType: contentType,
  size: 1,
  createdAt: DateTime.utc(2026, 1, 1),
);

Widget _host(MediaAsset asset, MediaThumbnailLoader loader) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 120,
        height: 120,
        child: MediaThumbnail(asset: asset, loader: loader),
      ),
    ),
  ),
);

void main() {
  testWidgets('loader resuelve bytes ⇒ pinta Image, sin placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_asset(), _FakeLoader(Future<Uint8List?>.value(_png1x1))),
    );
    await tester.pump(); // resuelve el FutureBuilder (futuro ya completo)

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsNothing);
  });

  testWidgets('loader resuelve null ⇒ placeholder por tipo (imagen)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_asset(), _FakeLoader(Future<Uint8List?>.value(null))),
    );
    await tester.pump();

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('placeholder de documento muestra el filename bajo el ícono', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _asset(contentType: 'application/pdf', filename: 'informe-q3.pdf'),
        _FakeLoader(Future<Uint8List?>.value(null)),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    expect(find.text('informe-q3.pdf'), findsOneWidget);
  });

  testWidgets('mientras el loader está pendiente ⇒ spinner', (tester) async {
    final pending = Completer<Uint8List?>();
    await tester.pumpWidget(_host(_asset(), _FakeLoader(pending.future)));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    pending.complete(null); // limpia el futuro pendiente al cerrar el test
  });
}
