import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/presentation/widgets/media_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MediaAsset _asset({required String contentType, required String filename}) =>
    MediaAsset(
      ref: 'tenant/o/media/x',
      // Sin previewUrl ⇒ placeholder directo (los documentos no renderizan como
      // imagen de todos modos: su previewUrl es el binario, no una miniatura).
      previewUrl: null,
      filename: filename,
      contentType: contentType,
      size: 1,
      createdAt: DateTime.utc(2026, 1, 1),
    );

Widget _host(MediaAsset asset) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 120,
        height: 120,
        child: MediaThumbnail(asset: asset),
      ),
    ),
  ),
);

void main() {
  testWidgets('tile de documento muestra el filename bajo el ícono', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_asset(contentType: 'application/pdf', filename: 'informe-q3.pdf')),
    );

    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    expect(find.text('informe-q3.pdf'), findsOneWidget);
  });

  testWidgets('tile de imagen (placeholder) NO muestra el filename', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_asset(contentType: 'image/png', filename: 'foto.png')),
    );

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    // El filename es ruido para imágenes (la miniatura es la identidad visual).
    expect(find.text('foto.png'), findsNothing);
  });
}
