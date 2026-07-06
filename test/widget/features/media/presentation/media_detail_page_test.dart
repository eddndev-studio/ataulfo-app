import 'dart:async';
import 'dart:ui' as ui;

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_danger_zone.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/repositories/media_preview_launcher.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/media/domain/repositories/media_thumbnail_loader.dart';
import 'package:ataulfo/features/media/presentation/bloc/media_detail_cubit.dart';
import 'package:ataulfo/features/media/presentation/pages/media_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MediaRepository {}

class _FakeLoader implements MediaThumbnailLoader {
  _FakeLoader(this._result);
  final Future<Uint8List?> _result;
  @override
  Future<Uint8List?> load(MediaAsset asset) => _result;
}

/// Launcher fake: registra qué URL se abrió y reporta éxito.
class _FakeLauncher implements MediaPreviewLauncher {
  final List<String> opened = <String>[];
  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return true;
  }
}

/// PNG real de [w]x[h] generado con el engine: el visor decodifica de verdad
/// (un fixture de bytes a mano no sobrevive al codec).
Future<Uint8List> _pngBytes(WidgetTester tester, int w, int h) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF336699),
    );
    final image = await recorder.endRecording().toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

MediaAsset _asset({
  String contentType = 'image/png',
  String filename = 'foto.png',
  String alias = '',
  int size = 1536,
  String? thumbnailUrl,
  int? durationMs,
}) => MediaAsset(
  ref: 'tenant/orgA/media/abc.png',
  previewUrl: 'https://x/sig',
  filename: filename,
  alias: alias,
  contentType: contentType,
  size: size,
  createdAt: DateTime.utc(2026, 6, 5, 14, 30),
  thumbnailUrl: thumbnailUrl,
  durationMs: durationMs,
);

/// Viewport alto: el detalle es una página larga (preview + metadata + zona
/// peligrosa) y los tests interactúan con su sección final sin scroll.
void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

// La página es content-only: el host emula el chrome que monta la ruta
// (Scaffold + AppBar con el título vivo del cubit). El loader default no
// entrega bytes (tile de ícono): decodificar imagen exige `tester.runAsync`
// (el decode corre fuera del fake-async), así que solo los tests de imagen
// pasan bytes reales y asientan con [_settleImage].
Widget _host(
  MediaAsset asset, {
  MediaThumbnailLoader? loader,
  MediaRepository? repo,
  MediaPreviewLauncher? launcher,
  bool readOnly = false,
}) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: BlocProvider<MediaDetailCubit>(
    create: (_) => MediaDetailCubit(repo: repo ?? _MockRepo(), asset: asset),
    child: Scaffold(
      appBar: AppBar(title: const MediaDetailTitle()),
      body: MediaDetailPage(
        loader: loader ?? _FakeLoader(Future<Uint8List?>.value(null)),
        launcher: launcher ?? _FakeLauncher(),
        readOnly: readOnly,
      ),
    ),
  ),
);

/// Monta [widget] con async REAL (el decode de imagen corre fuera del
/// fake-async del tester), espera a que el bitmap decodifique y pinta el
/// resultado.
Future<void> _pumpWithImage(WidgetTester tester, Widget widget) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(widget);
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  await tester.pump();
}

void main() {
  testWidgets('muestra metadata: filename, tipo, tamaño formateado', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_asset(filename: 'foto.png', size: 1536)));
    await tester.pump();

    expect(find.text('foto.png'), findsWidgets); // filename + título vivo
    expect(find.text('image/png'), findsOneWidget);
    expect(find.text('1.5 KB'), findsOneWidget); // formatBytes(1536)
  });

  testWidgets('el título vivo del AppBar es el displayName del cubit', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_asset(alias: 'Mi logo')));
    await tester.pump();

    // displayName = alias cuando existe: título + fila Alias.
    expect(find.text('Mi logo'), findsNWidgets(2));
  });

  testWidgets('con alias ⇒ la fila Alias muestra el alias', (tester) async {
    await tester.pumpWidget(_host(_asset(alias: 'Mi logo')));
    await tester.pump();
    expect(find.text('Alias'), findsOneWidget);
    expect(find.text('Mi logo'), findsWidgets);
  });

  testWidgets('sin alias ⇒ la fila Alias sigue viva con placeholder', (
    tester,
  ) async {
    // La edición vive en la superficie: la fila existe aunque no haya alias
    // (es la affordance para ponerle uno), con placeholder honesto.
    await tester.pumpWidget(_host(_asset()));
    await tester.pump();
    expect(find.text('Alias'), findsOneWidget);
    expect(find.text('Sin alias'), findsOneWidget);
    expect(find.byKey(const Key('media_detail.edit_alias')), findsOneWidget);
  });

  testWidgets('la card de metadata abre con el header de sección Detalles', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_asset()));
    await tester.pump();
    expect(find.text('Detalles'), findsOneWidget);
  });

  testWidgets('imagen con bytes ⇒ Image', (tester) async {
    final png = await _pngBytes(tester, 8, 8);
    await _pumpWithImage(
      tester,
      _host(
        _asset(contentType: 'image/png'),
        loader: _FakeLoader(Future<Uint8List?>.value(png)),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('documento ⇒ ícono del tipo', (tester) async {
    await tester.pumpWidget(
      _host(
        _asset(contentType: 'application/pdf', filename: 'x.pdf'),
        loader: _FakeLoader(Future<Uint8List?>.value(null)),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });

  testWidgets('video con duración ⇒ fila Duración formateada', (tester) async {
    await tester.pumpWidget(
      _host(
        _asset(
          contentType: 'video/mp4',
          filename: 'clip.mp4',
          durationMs: 65000,
        ),
        loader: _FakeLoader(Future<Uint8List?>.value(null)),
      ),
    );
    await tester.pump();
    expect(find.text('Duración'), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget); // formatDuration(65000)
  });

  testWidgets('sin duración (imagen) ⇒ no hay fila Duración', (tester) async {
    await tester.pumpWidget(_host(_asset()));
    await tester.pump();
    expect(find.text('Duración'), findsNothing);
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

    _tallViewport(tester);
    await tester.pumpWidget(_host(_asset()));
    await tester.pump();

    await tester.tap(find.byKey(const Key('media_detail.copy_ref')));
    await tester.pump();

    expect(calls, isNotEmpty);
    expect((calls.first.arguments as Map)['text'], 'tenant/orgA/media/abc.png');
    expect(find.text('Referencia copiada'), findsOneWidget);
  });

  group('zona peligrosa', () {
    testWidgets('borrar vive en la AppDangerZone al final, no en el chrome', (
      tester,
    ) async {
      _tallViewport(tester);
      await tester.pumpWidget(_host(_asset()));
      await tester.pump();

      expect(find.text('Zona peligrosa'), findsOneWidget);
      final button = find.byKey(const Key('media_detail.delete'));
      expect(button, findsOneWidget);
      // El botón destructivo es del kit y vive dentro de la zona.
      expect(
        find.ancestor(of: button, matching: find.byType(AppDangerZone)),
        findsOneWidget,
      );
      // El chrome no carga acciones destructivas.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(IconButton),
        ),
        findsNothing,
      );
    });

    testWidgets('borrar pide confirmación (título en pregunta) y al '
        'confirmar llama repo.delete', (tester) async {
      _tallViewport(tester);
      final repo = _MockRepo();
      when(() => repo.delete(any())).thenAnswer((_) async {});
      await tester.pumpWidget(_host(_asset(), repo: repo));
      await tester.pump();

      await tester.tap(find.byKey(const Key('media_detail.delete')));
      await tester.pumpAndSettle();
      expect(find.text('¿Borrar este archivo?'), findsOneWidget); // diálogo

      await tester.tap(find.text('Borrar')); // confirmar
      await tester.pumpAndSettle();

      verify(() => repo.delete('tenant/orgA/media/abc.png')).called(1);
    });

    testWidgets('el diálogo de borrado enfatiza la acción destructiva (DS)', (
      tester,
    ) async {
      // Cancelar=AppButton.text, Borrar=AppButton.danger: el confirmador
      // destructivo debe distinguirse visualmente, no ser un TextButton plano.
      _tallViewport(tester);
      final repo = _MockRepo();
      await tester.pumpWidget(_host(_asset(), repo: repo));
      await tester.pump();

      await tester.tap(find.byKey(const Key('media_detail.delete')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppButton, 'Borrar'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cancelar'), findsOneWidget);
    });

    testWidgets('cancelar el diálogo NO borra', (tester) async {
      _tallViewport(tester);
      final repo = _MockRepo();
      when(() => repo.delete(any())).thenAnswer((_) async {});
      await tester.pumpWidget(_host(_asset(), repo: repo));
      await tester.pump();

      await tester.tap(find.byKey(const Key('media_detail.delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(() => repo.delete(any()));
    });
  });

  testWidgets('mutación en vuelo ⇒ SIN scrim de página: el snapshot sigue '
      'pintado y el botón danger carga inline', (tester) async {
    _tallViewport(tester);
    final repo = _MockRepo();
    final gate = Completer<void>();
    when(() => repo.delete(any())).thenAnswer((_) => gate.future);
    await tester.pumpWidget(_host(_asset(), repo: repo));
    await tester.pump();

    await tester.tap(find.byKey(const Key('media_detail.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pump(); // busy:true, delete en vuelo

    // Nada de velo que tape la página (idioma: controles inertes).
    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == AppTokens.scrim,
      ),
      findsNothing,
    );
    // La metadata sigue visible bajo la mutación.
    expect(find.text('image/png'), findsOneWidget);
    // El feedback de la mutación vive en el propio botón (loading inline).
    expect(
      find.descendant(
        of: find.byKey(const Key('media_detail.delete')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('la metadata vive sobre AppCard, no en un Container ad-hoc', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_asset()));
    await tester.pump();

    expect(
      find.ancestor(of: find.text('Tipo'), matching: find.byType(AppCard)),
      findsOneWidget,
    );
  });

  testWidgets('renombrar (fila Alias) abre el form-sheet canónico', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_asset()));
    await tester.pump();

    await tester.tap(find.byKey(const Key('media_detail.edit_alias')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.backgroundColor, AppTokens.surface1);
    // H1 canónico + campo con su key de contrato + submit del kit.
    final h1 = tester.widget<Text>(find.text('Renombrar'));
    expect(h1.style?.fontSize, AppTokens.titleLSize);
    expect(find.byKey(const Key('media_detail.alias_field')), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Guardar'), findsOneWidget);
  });

  testWidgets('renombrar: editar y guardar llama repo.setAlias y refleja '
      'en fila Y título', (tester) async {
    final repo = _MockRepo();
    when(() => repo.setAlias(any(), any())).thenAnswer((_) async => 'Nuevo');
    await tester.pumpWidget(_host(_asset(filename: 'orig.png'), repo: repo));
    await tester.pump();

    await tester.tap(find.byKey(const Key('media_detail.edit_alias')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('media_detail.alias_field')),
      'Nuevo',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    verify(() => repo.setAlias('tenant/orgA/media/abc.png', 'Nuevo')).called(1);
    // El alias se refleja en la fila Y en el título vivo del AppBar.
    expect(find.text('Nuevo'), findsNWidgets(2));
  });

  testWidgets('renombrar y volver ⇒ pop devuelve true (changed)', (
    tester,
  ) async {
    final repo = _MockRepo();
    when(() => repo.setAlias(any(), any())).thenAnswer((_) async => 'Nuevo');
    final popResult = await _openEditSaveAndBack(tester, repo);
    expect(popResult, isTrue);
  });

  testWidgets('volver sin cambios ⇒ pop devuelve false', (tester) async {
    final repo = _MockRepo();
    bool? popResult;
    await _pushDetail(tester, repo, (r) => popResult = r);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(MediaDetailPage), findsNothing);
    expect(popResult, isFalse);
  });

  testWidgets('borrado exitoso ⇒ la página hace pop devolviendo true', (
    tester,
  ) async {
    _tallViewport(tester);
    final repo = _MockRepo();
    when(() => repo.delete(any())).thenAnswer((_) async {});
    bool? popResult;

    await _pushDetail(tester, repo, (r) => popResult = r);
    expect(find.byType(MediaDetailPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('media_detail.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();

    expect(find.byType(MediaDetailPage), findsNothing); // hizo pop
    expect(popResult, isTrue); // devolvió "cambió"
  });

  testWidgets('video ⇒ sin botón externo (reproduce in-app)', (tester) async {
    final launcher = _FakeLauncher();
    await tester.pumpWidget(
      _host(
        _asset(contentType: 'video/mp4', filename: 'clip.mp4'),
        loader: _FakeLoader(Future<Uint8List?>.value(null)),
        launcher: launcher,
      ),
    );
    await tester.pump();

    expect(find.text('Reproducir'), findsNothing);
    expect(find.text('Abrir'), findsNothing);
    expect(launcher.opened, isEmpty);
  });

  testWidgets('documento ⇒ botón Abrir', (tester) async {
    await tester.pumpWidget(
      _host(
        _asset(contentType: 'application/pdf', filename: 'doc.pdf'),
        loader: _FakeLoader(Future<Uint8List?>.value(null)),
      ),
    );
    await tester.pump();
    expect(find.text('Abrir'), findsOneWidget);
    expect(find.text('Reproducir'), findsNothing);
  });

  testWidgets('imagen ⇒ sin botón externo (preview inline)', (tester) async {
    await tester.pumpWidget(_host(_asset(contentType: 'image/png')));
    await tester.pump();
    expect(find.text('Reproducir'), findsNothing);
    expect(find.text('Abrir'), findsNothing);
  });

  testWidgets('el scroll reserva el inset inferior del sistema en su padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewPadding: const EdgeInsets.only(bottom: 34)),
            child: BlocProvider<MediaDetailCubit>(
              create: (_) =>
                  MediaDetailCubit(repo: _MockRepo(), asset: _asset()),
              child: Scaffold(
                body: MediaDetailPage(
                  loader: _FakeLoader(Future<Uint8List?>.value(null)),
                  launcher: _FakeLauncher(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.padding?.resolve(TextDirection.ltr).bottom, AppTokens.sp4 + 34);
  });

  group('readOnly (preview desde el picker)', () {
    testWidgets('sin edición ni zona peligrosa; la metadata sigue visible', (
      tester,
    ) async {
      _tallViewport(tester);
      await tester.pumpWidget(_host(_asset(), readOnly: true));
      await tester.pump();

      // Sin mutaciones: el preview del picker sólo mira.
      expect(find.byKey(const Key('media_detail.edit_alias')), findsNothing);
      expect(find.byKey(const Key('media_detail.delete')), findsNothing);
      expect(find.text('Zona peligrosa'), findsNothing);
      // La metadata y el ref (copiar) siguen ahí.
      expect(find.text('image/png'), findsOneWidget);
      expect(find.byKey(const Key('media_detail.copy_ref')), findsOneWidget);
    });

    testWidgets('por defecto (browse) sí ofrece renombrar y borrar', (
      tester,
    ) async {
      _tallViewport(tester);
      await tester.pumpWidget(_host(_asset()));
      await tester.pump();
      expect(find.byKey(const Key('media_detail.edit_alias')), findsOneWidget);
      expect(find.byKey(const Key('media_detail.delete')), findsOneWidget);
    });
  });

  group('doble-tap para hacer zoom', () {
    Future<void> doubleTapPreview(WidgetTester tester) async {
      final target = find.byType(InteractiveViewer);
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(target);
      // Deja resolver el reconocedor de doble tap.
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('doble tap acerca la imagen y otro doble tap vuelve a 1x', (
      tester,
    ) async {
      final png = await _pngBytes(tester, 8, 8);
      await _pumpWithImage(
        tester,
        _host(
          _asset(contentType: 'image/png'),
          loader: _FakeLoader(Future<Uint8List?>.value(png)),
        ),
      );

      double scale() => tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!
          .value
          .getMaxScaleOnAxis();

      expect(scale(), moreOrLessEquals(1.0));

      await doubleTapPreview(tester);
      expect(scale(), greaterThan(1.5));

      await doubleTapPreview(tester);
      expect(scale(), moreOrLessEquals(1.0));
    });
  });
}

/// Empuja el detalle sobre una pila de navegación (para observar el pop) con
/// el mismo chrome que monta la ruta real, y reporta el resultado vía [onPop].
Future<void> _pushDetail(
  WidgetTester tester,
  MediaRepository repo,
  void Function(bool?) onPop,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final r = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => BlocProvider<MediaDetailCubit>(
                      create: (_) =>
                          MediaDetailCubit(repo: repo, asset: _asset()),
                      child: Scaffold(
                        appBar: AppBar(title: const MediaDetailTitle()),
                        body: MediaDetailPage(
                          loader: _FakeLoader(Future<Uint8List?>.value(null)),
                          launcher: _FakeLauncher(),
                        ),
                      ),
                    ),
                  ),
                );
                onPop(r);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Empuja el detalle, renombra (guardar) y vuelve; devuelve el resultado del pop.
Future<bool?> _openEditSaveAndBack(
  WidgetTester tester,
  MediaRepository repo,
) async {
  bool? popResult;
  await _pushDetail(tester, repo, (r) => popResult = r);
  await tester.tap(find.byKey(const Key('media_detail.edit_alias')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('media_detail.alias_field')),
    'Nuevo',
  );
  await tester.tap(find.text('Guardar'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  return popResult;
}
