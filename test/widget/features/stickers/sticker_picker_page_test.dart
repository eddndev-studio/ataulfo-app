import 'dart:typed_data';

import 'package:ataulfo/features/stickers/domain/entities/sticker_job.dart';
import 'package:ataulfo/features/stickers/domain/repositories/sticker_repository.dart';
import 'package:ataulfo/features/stickers/presentation/bloc/sticker_cubit.dart';
import 'package:ataulfo/features/stickers/presentation/pages/sticker_picker_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements StickerRepository {
  _FakeRepo(this._jobs);
  final List<StickerJob> _jobs;

  @override
  Future<List<StickerJob>> list() async => _jobs;

  @override
  Future<String> generate(String motif) async => 'job-x';
}

Future<Uint8List?> _noThumb(String ref) async => null;

StickerJob _ready(String id, String ref) => StickerJob(
  id: id,
  motif: 'gracias',
  status: StickerStatus.done,
  resultMediaRef: ref,
  errorNote: '',
  createdAt: DateTime.utc(2026, 7, 8),
);

void main() {
  Widget host(_FakeRepo repo, {required void Function(String?) onResult}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final ref = await Navigator.of(context).push<String>(
                  MaterialPageRoute<String>(
                    builder: (_) => BlocProvider<StickerCubit>(
                      create: (_) => StickerCubit(
                        repo,
                        pollInterval: const Duration(hours: 1),
                      )..load(),
                      child: const StickerPickerPage(resolveThumb: _noThumb),
                    ),
                  ),
                );
                onResult(ref);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('elegir un sticker cierra el picker con su ref', (tester) async {
    String? result = 'unset';
    final repo = _FakeRepo([_ready('s1', 'org/media/s1.webp')]);
    await tester.pumpWidget(host(repo, onResult: (r) => result = r));

    await tester.tap(find.text('abrir'));
    // Frames explícitos (no pumpAndSettle): basta avanzar el push y la
    // resolución del thumbnail (aquí null → glifo de respaldo) para tocar la
    // celda; no dependemos de asentar las animaciones de ruta.
    await tester.pump(); // inicia el push
    await tester.pump(const Duration(milliseconds: 400)); // transición de ruta
    await tester.pump(); // resuelve el load() del cubit

    // El picker está abierto y muestra la celda seleccionable.
    expect(find.byKey(const Key('sticker_pick.org/media/s1.webp')), findsOne);
    await tester.tap(find.byKey(const Key('sticker_pick.org/media/s1.webp')));
    await tester.pump(); // inicia el pop
    await tester.pump(
      const Duration(milliseconds: 400),
    ); // transición de vuelta

    expect(result, 'org/media/s1.webp');
  });

  testWidgets(
    'un thumbnail que resuelve a null cae a un glifo, no gira sin fin',
    (tester) async {
      final repo = _FakeRepo([_ready('s1', 'org/media/s1.webp')]);
      await tester.pumpWidget(host(repo, onResult: (_) {}));

      await tester.tap(find.text('abrir'));
      await tester.pump(); // inicia el push
      await tester.pump(
        const Duration(milliseconds: 400),
      ); // transición de ruta
      await tester.pump(); // resuelve el load() del cubit → grid + celdas
      await tester.pump(); // resuelve resolveThumb (null) → marca el intento

      // La celda cuyo thumbnail resolvió a null muestra el glifo de respaldo, no
      // un spinner girando para siempre (paridad con la pantalla de Ajustes).
      expect(find.byIcon(Icons.emoji_emotions_outlined), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('sin stickers listos ofrece el estado vacío', (tester) async {
    final repo = _FakeRepo(const []);
    await tester.pumpWidget(host(repo, onResult: (_) {}));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aún no tienes stickers'), findsOneWidget);
  });
}
