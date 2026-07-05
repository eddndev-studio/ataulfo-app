import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
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

// Detalle como home (display/copy: no requiere pila de navegación).
Widget _host(
  MediaAsset asset, {
  MediaThumbnailLoader? loader,
  MediaRepository? repo,
  MediaPreviewLauncher? launcher,
}) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: BlocProvider<MediaDetailCubit>(
    create: (_) => MediaDetailCubit(repo: repo ?? _MockRepo(), asset: asset),
    child: MediaDetailPage(
      loader: loader ?? _FakeLoader(Future<Uint8List?>.value(_png1x1)),
      launcher: launcher ?? _FakeLauncher(),
    ),
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

  testWidgets('con alias ⇒ muestra la fila Alias', (tester) async {
    await tester.pumpWidget(_host(_asset(alias: 'Mi logo')));
    await tester.pump();
    expect(find.text('Alias'), findsOneWidget);
    expect(find.text('Mi logo'), findsWidgets); // alias + título (displayName)
  });

  testWidgets('sin alias ⇒ no hay fila Alias', (tester) async {
    await tester.pumpWidget(_host(_asset()));
    await tester.pump();
    expect(find.text('Alias'), findsNothing);
  });

  testWidgets('imagen con bytes ⇒ Image', (tester) async {
    await tester.pumpWidget(_host(_asset(contentType: 'image/png')));
    await tester.pump();
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

  testWidgets('video con poster ⇒ preview pinta Image (no sólo el ícono)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _asset(
          contentType: 'video/mp4',
          filename: 'clip.mp4',
          thumbnailUrl: 'https://x/poster.jpg',
        ),
        loader: _FakeLoader(Future<Uint8List?>.value(_png1x1)),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
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
    await tester.pump();

    expect(calls, isNotEmpty);
    expect((calls.first.arguments as Map)['text'], 'tenant/orgA/media/abc.png');
    expect(find.text('Referencia copiada'), findsOneWidget);
  });

  testWidgets('borrar pide confirmación y al confirmar llama repo.delete', (
    tester,
  ) async {
    final repo = _MockRepo();
    when(() => repo.delete(any())).thenAnswer((_) async {});
    await tester.pumpWidget(_host(_asset(), repo: repo));
    await tester.pump();

    await tester.tap(find.byKey(const Key('media_detail.delete')));
    await tester.pumpAndSettle();
    expect(find.text('Borrar archivo'), findsOneWidget); // diálogo

    await tester.tap(find.text('Borrar')); // confirmar
    await tester.pumpAndSettle();

    verify(() => repo.delete('tenant/orgA/media/abc.png')).called(1);
  });

  testWidgets('el diálogo de borrado enfatiza la acción destructiva (DS)', (
    tester,
  ) async {
    // Cancelar=AppButton.text, Borrar=AppButton.danger: el confirmador
    // destructivo debe distinguirse visualmente, no ser un TextButton plano.
    final repo = _MockRepo();
    await tester.pumpWidget(_host(_asset(), repo: repo));
    await tester.pump();

    await tester.tap(find.byKey(const Key('media_detail.delete')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppButton, 'Borrar'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Cancelar'), findsOneWidget);
  });

  testWidgets('cancelar el diálogo NO borra', (tester) async {
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

  testWidgets('renombrar abre el form-sheet canónico, no un diálogo', (
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

  testWidgets('renombrar: editar y guardar llama repo.setAlias y refleja', (
    tester,
  ) async {
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
    // El alias mostrado se actualizó (fila Alias + título displayName).
    expect(find.text('Nuevo'), findsWidgets);
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
    final repo = _MockRepo();
    when(() => repo.delete(any())).thenAnswer((_) async {});
    bool? popResult;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popResult = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => BlocProvider<MediaDetailCubit>(
                        create: (_) =>
                            MediaDetailCubit(repo: repo, asset: _asset()),
                        child: MediaDetailPage(
                          loader: _FakeLoader(Future<Uint8List?>.value(null)),
                          launcher: _FakeLauncher(),
                        ),
                      ),
                    ),
                  );
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
    expect(find.byType(MediaDetailPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('media_detail.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();

    expect(find.byType(MediaDetailPage), findsNothing); // hizo pop
    expect(popResult, isTrue); // devolvió "cambió"
  });

  testWidgets('video ⇒ botón Reproducir abre la previewUrl en el visor', (
    tester,
  ) async {
    final launcher = _FakeLauncher();
    await tester.pumpWidget(
      _host(
        _asset(contentType: 'video/mp4', filename: 'clip.mp4'),
        loader: _FakeLoader(Future<Uint8List?>.value(null)),
        launcher: launcher,
      ),
    );
    await tester.pump();

    expect(find.text('Reproducir'), findsOneWidget);
    await tester.tap(find.text('Reproducir'));
    await tester.pump();

    expect(launcher.opened, <String>['https://x/sig']); // la previewUrl firmada
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
}

/// Empuja el detalle sobre una pila de navegación (para observar el pop) y
/// reporta el resultado vía [onPop].
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
                      child: MediaDetailPage(
                        loader: _FakeLoader(Future<Uint8List?>.value(null)),
                        launcher: _FakeLauncher(),
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
