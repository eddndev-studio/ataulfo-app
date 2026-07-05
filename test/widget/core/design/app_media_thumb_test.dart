import 'dart:async';
import 'dart:typed_data';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_media_thumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('AppMediaThumb', () {
    testWidgets('con bytes válidos pinta la imagen con fit cover', (
      tester,
    ) async {
      await pump(
        tester,
        AppMediaThumb(
          mediaRef: 'tenant/o/media/a.png',
          kind: AppMediaKind.image,
          loader: (_) async => _png1x1,
        ),
      );
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(
        find.byKey(const ValueKey('app_media_thumb.image')),
      );
      expect(image.fit, BoxFit.cover);
      expect(
        find.byKey(const ValueKey('app_media_thumb.fallback')),
        findsNothing,
      );
    });

    testWidgets(
      'mientras resuelve muestra un placeholder QUIETO (sin spinner)',
      (tester) async {
        final never = Completer<Uint8List?>();
        await pump(
          tester,
          AppMediaThumb(
            mediaRef: 'tenant/o/media/a.png',
            kind: AppMediaKind.image,
            loader: (_) => never.future,
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('app_media_thumb.loading')),
          findsOneWidget,
        );
        // Quieto a propósito: sin animación indefinida el host puede usar
        // pumpAndSettle y el placeholder no compite visualmente con el form.
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.byKey(const ValueKey('app_media_thumb.image')),
          findsNothing,
        );
      },
    );

    testWidgets('loader null ⇒ glifo por tipo de media (fallback honesto)', (
      tester,
    ) async {
      await pump(
        tester,
        AppMediaThumb(
          mediaRef: 'tenant/o/media/v.mp4',
          kind: AppMediaKind.video,
          loader: (_) async => null,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('app_media_thumb.fallback')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      expect(find.byKey(const ValueKey('app_media_thumb.image')), findsNothing);
    });

    testWidgets('glifo por kind: audio y documento', (tester) async {
      await pump(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppMediaThumb(
              mediaRef: 'tenant/o/media/a.ogg',
              kind: AppMediaKind.audio,
              loader: (_) async => null,
            ),
            AppMediaThumb(
              mediaRef: 'tenant/o/media/d.pdf',
              kind: AppMediaKind.document,
              loader: (_) async => null,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.audiotrack_outlined), findsOneWidget);
      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
    });

    testWidgets('bytes corruptos ⇒ glifo, nunca el ícono roto de Flutter', (
      tester,
    ) async {
      await pump(
        tester,
        AppMediaThumb(
          mediaRef: 'tenant/o/media/x.png',
          kind: AppMediaKind.image,
          loader: (_) async => Uint8List.fromList(<int>[0, 1, 2, 3]),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('app_media_thumb.fallback')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('cambia el mediaRef ⇒ re-resuelve con el ref nuevo', (
      tester,
    ) async {
      final requested = <String>[];
      Future<Uint8List?> loader(String ref) async {
        requested.add(ref);
        return ref.endsWith('b.png') ? _png1x1 : null;
      }

      await pump(
        tester,
        AppMediaThumb(
          mediaRef: 'tenant/o/media/a.png',
          kind: AppMediaKind.image,
          loader: loader,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('app_media_thumb.fallback')),
        findsOneWidget,
      );

      await pump(
        tester,
        AppMediaThumb(
          mediaRef: 'tenant/o/media/b.png',
          kind: AppMediaKind.image,
          loader: loader,
        ),
      );
      await tester.pumpAndSettle();

      expect(requested, <String>[
        'tenant/o/media/a.png',
        'tenant/o/media/b.png',
      ]);
      expect(
        find.byKey(const ValueKey('app_media_thumb.image')),
        findsOneWidget,
      );
    });

    testWidgets(
      're-render con el MISMO ref no re-resuelve (loader es closure)',
      (tester) async {
        var calls = 0;
        await pump(
          tester,
          StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppMediaThumb(
                  mediaRef: 'tenant/o/media/a.png',
                  kind: AppMediaKind.image,
                  // Closure nueva en cada build: la identidad del loader NO debe
                  // disparar re-resolución (sólo el mediaRef).
                  loader: (_) async {
                    calls++;
                    return _png1x1;
                  },
                ),
                TextButton(
                  onPressed: () => setState(() {}),
                  child: const Text('rebuild'),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('rebuild'));
        await tester.pumpAndSettle();

        expect(calls, 1);
      },
    );

    testWidgets('respeta size (cuadrada) y radios del kit', (tester) async {
      await pump(
        tester,
        AppMediaThumb(
          mediaRef: 'tenant/o/media/a.png',
          kind: AppMediaKind.image,
          size: 56,
          loader: (_) async => _png1x1,
        ),
      );
      await tester.pumpAndSettle();

      final box = tester.getSize(find.byType(AppMediaThumb));
      expect(box, const Size(56, 56));

      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(AppMediaThumb),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(AppTokens.radiusChip));
    });
  });
}
