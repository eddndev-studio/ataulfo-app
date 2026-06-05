import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/repositories/media_thumbnail_loader.dart';
import 'package:ataulfo/features/media/presentation/pages/media_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLoader implements MediaThumbnailLoader {
  _FakeLoader(this._result);
  final Future<Uint8List?> _result;
  @override
  Future<Uint8List?> load(MediaAsset asset) => _result;
}

// PNG 1x1 transparente válido.
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
  String alias = '',
  int size = 1536,
}) => MediaAsset(
  ref: 'tenant/orgA/media/abc.png',
  previewUrl: 'https://x/sig',
  filename: filename,
  alias: alias,
  contentType: contentType,
  size: size,
  createdAt: DateTime.utc(2026, 6, 5, 14, 30),
);

Widget _host(MediaAsset asset, {MediaThumbnailLoader? loader}) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: MediaDetailPage(
    asset: asset,
    loader: loader ?? _FakeLoader(Future<Uint8List?>.value(_png1x1)),
  ),
);

void main() {
  testWidgets('muestra metadata: filename, tipo, tamaño formateado', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_asset(filename: 'foto.png', size: 1536)));
    await tester.pump();

    expect(find.text('foto.png'), findsWidgets); // filename + título
    expect(find.text('image/png'), findsOneWidget);
    expect(find.text('1.5 KB'), findsOneWidget); // formatBytes(1536)
  });

  testWidgets('fila de alias sólo cuando el alias no está vacío', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_asset(alias: 'Mi logo')));
    await tester.pump();
    expect(find.text('Alias'), findsOneWidget);
    expect(find.text('Mi logo'), findsWidgets); // alias + título (displayName)

    await tester.pumpWidget(_host(_asset()));
    await tester.pump();
    expect(find.text('Alias'), findsNothing);
  });

  testWidgets('imagen con bytes ⇒ Image; documento ⇒ ícono', (tester) async {
    await tester.pumpWidget(_host(_asset(contentType: 'image/png')));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);

    await tester.pumpWidget(
      _host(
        _asset(contentType: 'application/pdf', filename: 'x.pdf'),
        loader: _FakeLoader(Future<Uint8List?>.value(null)),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });

  testWidgets('copiar ref ⇒ Clipboard.setData con el ref BARE + snackbar', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(_host(_asset()));
    await tester.pump();

    await tester.tap(find.byKey(const Key('media_detail.copy_ref')));
    await tester.pump(); // ejecuta el onPressed async + muestra snackbar

    expect(calls, isNotEmpty);
    expect(calls.first.arguments['text'], 'tenant/orgA/media/abc.png');
    expect(find.text('Referencia copiada'), findsOneWidget);
  });
}
