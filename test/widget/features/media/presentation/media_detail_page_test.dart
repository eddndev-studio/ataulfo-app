import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/failures/media_failure.dart';
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

// Detalle como home (display/copy: no requiere pila de navegación).
Widget _host(
  MediaAsset asset, {
  MediaThumbnailLoader? loader,
  MediaRepository? repo,
}) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: BlocProvider<MediaDetailCubit>(
    create: (_) => MediaDetailCubit(repo: repo ?? _MockRepo(), asset: asset),
    child: MediaDetailPage(
      loader: loader ?? _FakeLoader(Future<Uint8List?>.value(_png1x1)),
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
    expect(calls.first.arguments['text'], 'tenant/orgA/media/abc.png');
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
