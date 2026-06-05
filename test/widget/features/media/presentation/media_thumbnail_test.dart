import 'dart:async';
import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/repositories/media_thumbnail_loader.dart';
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

/// Loader que responde según el `ref` y registra qué se le pidió — para
/// verificar que el widget re-resuelve cuando el grid recicla la celda a otro
/// asset (didUpdateWidget).
class _RefLoader implements MediaThumbnailLoader {
  _RefLoader(this._byRef);
  final Map<String, Uint8List?> _byRef;
  final List<String> requested = <String>[];
  @override
  Future<Uint8List?> load(MediaAsset asset) async {
    requested.add(asset.ref);
    return _byRef[asset.ref];
  }
}

MediaAsset _assetRef(String ref) => MediaAsset(
  ref: ref,
  previewUrl: 'https://x/sig',
  filename: 'f.png',
  contentType: 'image/png',
  size: 1,
  createdAt: DateTime.utc(2026, 1, 1),
);

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
  String alias = '',
}) => MediaAsset(
  ref: 'tenant/o/media/x',
  previewUrl: 'https://x/sig',
  filename: filename,
  alias: alias,
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

  testWidgets('caption muestra el displayName (alias) sobre la miniatura', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _asset(alias: 'Mi logo', filename: 'IMG_2231.png'),
        _FakeLoader(Future<Uint8List?>.value(_png1x1)),
      ),
    );
    await tester.pump();

    // La imagen se pinta y el caption rotula con el alias (no el filename).
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Mi logo'), findsOneWidget);
    expect(find.text('IMG_2231.png'), findsNothing);
  });

  testWidgets('caption cae al filename cuando no hay alias', (tester) async {
    await tester.pumpWidget(
      _host(
        _asset(filename: 'foto.png'),
        _FakeLoader(Future<Uint8List?>.value(_png1x1)),
      ),
    );
    await tester.pump();

    expect(find.text('foto.png'), findsOneWidget);
  });

  testWidgets('mientras el loader está pendiente ⇒ spinner', (tester) async {
    final pending = Completer<Uint8List?>();
    await tester.pumpWidget(_host(_asset(), _FakeLoader(pending.future)));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    pending.complete(null); // limpia el futuro pendiente al cerrar el test
  });

  testWidgets('cambia el ref ⇒ re-resuelve vía el loader (didUpdateWidget)', (
    tester,
  ) async {
    final loader = _RefLoader(<String, Uint8List?>{
      'tenant/o/media/x': null, // ⇒ placeholder
      'tenant/o/media/y': _png1x1, // ⇒ Image
    });
    Widget at(String ref) => MaterialApp(
      theme: AppDesignTheme.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 120,
            height: 120,
            // Misma Key ⇒ el segundo pump entra por didUpdateWidget, no initState.
            child: MediaThumbnail(
              key: const Key('t'),
              asset: _assetRef(ref),
              loader: loader,
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(at('tenant/o/media/x'));
    await tester.pump();
    expect(find.byType(Image), findsNothing);

    await tester.pumpWidget(at('tenant/o/media/y'));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);

    // Re-resolvió al cambiar el ref (no sirvió la resolución vieja).
    expect(loader.requested, <String>['tenant/o/media/x', 'tenant/o/media/y']);
  });

  testWidgets(
    'aparece la miniatura (null→source) con el mismo ref ⇒ re-resuelve el poster',
    (tester) async {
      // Loader que sólo devuelve bytes si el asset tiene fuente de miniatura:
      // simula un video que entra sin derivar y luego recibe su poster.
      final loader = _SourceAwareLoader(_png1x1);
      MediaAsset video({String? thumb}) => MediaAsset(
        ref: 'tenant/o/media/clip.mp4',
        previewUrl: 'https://x/clip.mp4', // original, no renderable
        filename: 'clip.mp4',
        contentType: 'video/mp4',
        size: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        thumbnailUrl: thumb,
      );
      Widget at(MediaAsset a) => MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: MediaThumbnail(
                key: const Key('t'),
                asset: a,
                loader: loader,
              ),
            ),
          ),
        ),
      );

      // Sin derivar ⇒ placeholder (ícono de video), sin Image.
      await tester.pumpWidget(at(video(thumb: null)));
      await tester.pump();
      expect(find.byType(Image), findsNothing);

      // Llega el poster con el MISMO ref ⇒ debe re-resolver y pintar la imagen.
      await tester.pumpWidget(at(video(thumb: 'https://x/poster.jpg')));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
    },
  );
}

/// Loader que responde según haya o no fuente de miniatura renderable.
class _SourceAwareLoader implements MediaThumbnailLoader {
  _SourceAwareLoader(this._bytes);
  final Uint8List _bytes;
  @override
  Future<Uint8List?> load(MediaAsset asset) async =>
      asset.thumbnailSourceUrl == null ? null : _bytes;
}
