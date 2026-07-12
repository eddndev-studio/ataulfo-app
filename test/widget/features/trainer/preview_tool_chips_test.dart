import 'package:ataulfo/core/design/tool_glyphs.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/trainer/domain/entities/preview_item.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/preview_bloc.dart';
import 'package:ataulfo/features/trainer/presentation/pages/preview_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPreviewRepo extends Mock implements PreviewRepository {}

class _MockPicker extends Mock implements MediaFilePicker {}

Future<void> _pump(WidgetTester tester, List<PreviewItem> items) async {
  final repo = _MockPreviewRepo();
  when(
    () => repo.transcript(templateId: 't1'),
  ).thenAnswer((_) async => PreviewTranscript(items: items));
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<PreviewBloc>(
        create: (_) =>
            PreviewBloc(repo: repo, templateId: 't1')
              ..add(const PreviewStarted()),
        child: const PreviewPage(templateId: 't1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<PreviewItem> _withToolItems() => <PreviewItem>[
  PreviewItem(kind: 'user', text: 'hola', at: DateTime.utc(2026)),
  PreviewItem(
    kind: 'tool',
    tool: 'read_document',
    summary: 'Leyó el documento politicas-envio',
    at: DateTime.utc(2026),
  ),
  PreviewItem(
    kind: 'tool',
    tool: 'get_current_time',
    summary: 'Consultó la hora',
    at: DateTime.utc(2026),
  ),
  PreviewItem(kind: 'bot', text: 'enviamos en 24h', at: DateTime.utc(2026)),
];

void main() {
  testWidgets('las lecturas (kind tool) quedan OCULTAS por defecto — y no '
      'dejan burbujas vacías', (tester) async {
    await _pump(tester, _withToolItems());

    expect(find.textContaining('politicas-envio'), findsNothing);
    expect(find.textContaining('Consultó la hora'), findsNothing);
    // Lo importante sigue visible.
    expect(find.text('hola'), findsOneWidget);
    expect(find.text('enviamos en 24h'), findsOneWidget);
    // El toggle existe en el app bar.
    expect(find.byKey(const Key('preview.tools_toggle')), findsOneWidget);
  });

  testWidgets('el toggle muestra los chips de herramientas y vuelve a '
      'ocultarlos', (tester) async {
    await _pump(tester, _withToolItems());

    await tester.tap(find.byKey(const Key('preview.tools_toggle')));
    await tester.pumpAndSettle();
    expect(find.textContaining('politicas-envio'), findsOneWidget);
    expect(find.textContaining('Consultó la hora'), findsOneWidget);

    await tester.tap(find.byKey(const Key('preview.tools_toggle')));
    await tester.pumpAndSettle();
    expect(find.textContaining('politicas-envio'), findsNothing);
  });

  testWidgets('el chip de lectura toma el glifo del catálogo CENTRAL, no un '
      'mapa local del preview', (tester) async {
    await _pump(tester, <PreviewItem>[
      PreviewItem(kind: 'user', text: '¿hora?', at: DateTime.utc(2026)),
      PreviewItem(
        kind: 'tool',
        tool: 'get_current_time',
        summary: 'Consultó la hora',
        at: DateTime.utc(2026),
      ),
    ]);
    // Las lecturas están ocultas por defecto: enciende el toggle.
    await tester.tap(find.byKey(const Key('preview.tools_toggle')));
    await tester.pumpAndSettle();
    // El catálogo central pinta get_current_time con schedule_outlined; el
    // mapa local del preview usaba Icons.schedule — el ícono los distingue.
    expect(find.byIcon(toolIconFor('get_current_time')), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsNothing);
  });

  testWidgets('el chip de efecto toma el glifo del catálogo central', (
    tester,
  ) async {
    await _pump(tester, <PreviewItem>[
      PreviewItem(kind: 'user', text: 'etiqueta', at: DateTime.utc(2026)),
      PreviewItem(
        kind: 'action',
        tool: 'apply_label',
        summary: 'Etiquetaría como VIP',
        at: DateTime.utc(2026),
      ),
    ]);
    expect(find.byIcon(toolIconFor('apply_label')), findsOneWidget);
  });

  testWidgets('sin items tool el toggle no aparece (nada que mostrar)', (
    tester,
  ) async {
    await _pump(tester, <PreviewItem>[
      PreviewItem(kind: 'user', text: 'hola', at: DateTime.utc(2026)),
      PreviewItem(kind: 'bot', text: '¡Hola!', at: DateTime.utc(2026)),
    ]);
    expect(find.byKey(const Key('preview.tools_toggle')), findsNothing);
  });

  testWidgets('el clip del demo guarda el adjunto y pinta el chip con ✕', (
    tester,
  ) async {
    final repo = _MockPreviewRepo();
    final picker = _MockPicker();
    when(
      () => repo.transcript(templateId: 't1'),
    ).thenAnswer((_) async => const PreviewTranscript(items: <PreviewItem>[]));
    when(() => picker.pick()).thenAnswer(
      (_) async =>
          PickedMedia(bytes: Uint8List.fromList(<int>[1]), filename: 'f.png'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<PreviewBloc>(
          create: (_) =>
              PreviewBloc(repo: repo, templateId: 't1', picker: picker)
                ..add(const PreviewStarted()),
          child: const PreviewPage(templateId: 't1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('preview.attach')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('preview.pending_att.f.png')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('preview.pending_att.f.png')), findsNothing);
  });
}
