import 'dart:typed_data';

import 'package:ataulfo/core/design/widgets/app_starter_chip.dart';
import 'package:ataulfo/features/stickers/domain/entities/sticker_job.dart';
import 'package:ataulfo/features/stickers/domain/repositories/sticker_repository.dart';
import 'package:ataulfo/features/stickers/presentation/bloc/sticker_cubit.dart';
import 'package:ataulfo/features/stickers/presentation/pages/stickers_page.dart';
import 'package:ataulfo/features/stickers/presentation/sticker_motifs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements StickerRepository {
  _FakeRepo(this._jobs);
  final List<StickerJob> _jobs;
  String? generated;

  @override
  Future<List<StickerJob>> list() async => _jobs;

  @override
  Future<String> generate(String motif) async {
    generated = motif;
    return 'job-new';
  }
}

Future<Uint8List?> _noThumb(String ref) async => null;

void main() {
  Widget host(_FakeRepo repo) => MaterialApp(
    home: BlocProvider<StickerCubit>(
      create: (_) =>
          StickerCubit(repo, pollInterval: const Duration(hours: 1))..load(),
      child: const StickersPage(resolveThumb: _noThumb),
    ),
  );

  testWidgets('vacío: ofrece los motivos y el estado vacío', (tester) async {
    final repo = _FakeRepo(const []);
    await tester.pumpWidget(host(repo));
    await tester.pumpAndSettle();

    expect(find.text('Genera un sticker'), findsOneWidget);
    expect(find.text('¡Gracias!'), findsOneWidget);
    expect(find.text('Aún no tienes stickers.'), findsOneWidget);
  });

  testWidgets('tocar un motivo lo genera', (tester) async {
    final repo = _FakeRepo(const []);
    await tester.pumpWidget(host(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('¡Oferta!'));
    await tester.pumpAndSettle();
    expect(repo.generated, 'oferta');
  });

  testWidgets('los motivos usan chips de sugerencia del sistema', (
    tester,
  ) async {
    final repo = _FakeRepo(const []);
    await tester.pumpWidget(host(repo));
    await tester.pumpAndSettle();

    // Mismo idioma de "sugerencia" que el chat de asistente/entrenador, no el
    // ActionChip de Material con su borde claro.
    expect(find.byType(AppStarterChip), findsNWidgets(stickerMotifs.length));
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('con jobs pinta el grid (celdas por job)', (tester) async {
    final repo = _FakeRepo([
      StickerJob(
        id: 's1',
        motif: 'gracias',
        status: StickerStatus.queued,
        resultMediaRef: '',
        errorNote: '',
        createdAt: DateTime.utc(2026, 7, 8),
      ),
    ]);
    await tester.pumpWidget(host(repo));
    // pump (no pumpAndSettle): la celda en curso tiene un spinner que anima sin
    // fin y nunca «settlea». Dos frames bastan para resolver el load async.
    await tester.pump();
    await tester.pump();

    expect(find.text('Tus stickers'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
}
