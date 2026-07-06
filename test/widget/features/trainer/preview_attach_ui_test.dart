import 'dart:convert';
import 'dart:typed_data';

import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/trainer/domain/entities/preview_item.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/preview_bloc.dart';
import 'package:ataulfo/features/trainer/presentation/pages/preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPreviewRepo extends Mock implements PreviewRepository {}

class _MockPicker extends Mock implements MediaFilePicker {}

/// PNG 4x4 válido (con bytes de imagen reales el chip pinta miniatura).
final _pngBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAADklEQVR4nGNoQAIMxHEAcFIYAYPG8BkAAAAASUVORK5CYII=',
  ),
);

void main() {
  late _MockPreviewRepo repo;
  late _MockPicker picker;

  setUp(() {
    repo = _MockPreviewRepo();
    picker = _MockPicker();
    when(
      () => repo.transcript(templateId: 't1'),
    ).thenAnswer((_) async => const PreviewTranscript(items: <PreviewItem>[]));
  });

  Widget host() => MaterialApp(
    home: BlocProvider<PreviewBloc>(
      create: (_) =>
          PreviewBloc(repo: repo, templateId: 't1', picker: picker)
            ..add(const PreviewStarted()),
      child: const PreviewPage(templateId: 't1'),
    ),
  );

  testWidgets(
    'el tooltip de adjuntar promete lo que el producto soporta (imagen o PDF)',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.byTooltip('Adjuntar imagen o PDF'), findsOneWidget);
      expect(find.byTooltip('Adjuntar imagen, PDF o audio'), findsNothing);
    },
  );

  testWidgets(
    'el chip pendiente pinta miniatura para imagen e ícono por tipo para PDF',
    (tester) async {
      when(() => picker.pick()).thenAnswer(
        (_) async => PickedMedia(bytes: _pngBytes, filename: 'foto.png'),
      );
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('preview.attach')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('preview.pending_thumb.foto.png')),
        findsOneWidget,
      );

      when(() => picker.pick()).thenAnswer(
        (_) async => PickedMedia(
          bytes: Uint8List.fromList(<int>[1, 2]),
          filename: 'contrato.pdf',
        ),
      );
      await tester.tap(find.byKey(const Key('preview.attach')));
      await tester.pumpAndSettle();
      final chip = find.byKey(const Key('preview.pending_att.contrato.pdf'));
      expect(chip, findsOneWidget);
      expect(
        find.descendant(
          of: chip,
          matching: find.byIcon(Icons.description_outlined),
        ),
        findsOneWidget,
      );
    },
  );
}
