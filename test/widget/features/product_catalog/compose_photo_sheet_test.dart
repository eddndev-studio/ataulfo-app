import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/product_catalog/domain/entities/composition_job.dart';
import 'package:ataulfo/features/product_catalog/domain/entities/product.dart';
import 'package:ataulfo/features/product_catalog/domain/failures/composition_failure.dart';
import 'package:ataulfo/features/product_catalog/domain/repositories/composition_repository.dart';
import 'package:ataulfo/features/product_catalog/presentation/widgets/compose_photo_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _product = Product(
  id: 'p1',
  kind: ProductKind.product,
  name: 'Mango Ataulfo',
  description: '',
  category: '',
  priceCents: 0,
  priceDisplay: '',
  mediaRef: 'ref/original.png',
  active: true,
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

CompositionJob _job(
  String id,
  CompositionStatus status, {
  String errorNote = '',
}) => CompositionJob(
  id: id,
  preset: 'estudio-blanco',
  model: '',
  status: status,
  resultMediaRef: status == CompositionStatus.done ? 'ref/out.png' : '',
  errorNote: errorNote,
  createdAt: DateTime.utc(2026, 7, 8, 10),
);

/// Repo guionizado: cada listJobs consume el siguiente paso (el último se
/// repite); las mutaciones registran y responden con el failure configurado.
class _FakeRepo implements CompositionRepository {
  _FakeRepo(this.script);

  final List<List<CompositionJob>> script;
  int listCalls = 0;

  String? composedPreset;
  bool? composedPremium;
  CompositionFailure? composeFailure;

  final List<String> accepted = <String>[];
  CompositionFailure? acceptFailure;

  final List<String> discarded = <String>[];
  CompositionFailure? discardFailure;

  @override
  Future<List<CompositionJob>> listJobs(String productId) async {
    final step = script[listCalls.clamp(0, script.length - 1)];
    listCalls++;
    return step;
  }

  @override
  Future<String> compose({
    required String productId,
    required String preset,
    bool premium = false,
  }) async {
    final f = composeFailure;
    if (f != null) throw f;
    composedPreset = preset;
    composedPremium = premium;
    return 'j-nuevo';
  }

  @override
  Future<void> accept(String jobId) async {
    final f = acceptFailure;
    if (f != null) throw f;
    accepted.add(jobId);
  }

  @override
  Future<void> discard(String jobId) async {
    final f = discardFailure;
    if (f != null) throw f;
    discarded.add(jobId);
  }
}

void main() {
  late String? popped;
  late bool closed;

  Future<void> pumpAndOpen(WidgetTester tester, _FakeRepo repo) async {
    popped = null;
    closed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await ComposePhotoSheet.open(
                  context,
                  product: _product,
                  repo: repo,
                  thumbBytes: (_) async => null,
                );
                closed = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  /// Desmonta el árbol para cerrar el cubit (y su timer de poll) antes de
  /// que termine el test.
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(Container());
  }

  testWidgets('sin composiciones ⇒ estado vacío con CTA', (tester) async {
    await pumpAndOpen(tester, _FakeRepo(<List<CompositionJob>>[[]]));
    expect(find.byKey(const Key('compose_photo.empty')), findsOneWidget);
    expect(find.byKey(const Key('compose_photo.new')), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('chips por estado y nota del fallo', (tester) async {
    await pumpAndOpen(
      tester,
      _FakeRepo(<List<CompositionJob>>[
        <CompositionJob>[
          _job('j1', CompositionStatus.queued),
          _job('j2', CompositionStatus.running),
          _job('j3', CompositionStatus.done),
          _job(
            'j4',
            CompositionStatus.failed,
            errorNote: 'la foto salió borrosa',
          ),
        ],
      ]),
    );
    expect(find.text('En cola'), findsOneWidget);
    expect(find.text('Creando…'), findsOneWidget);
    expect(find.text('Lista'), findsOneWidget);
    expect(find.text('Falló'), findsOneWidget);
    expect(find.text('la foto salió borrosa'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('DONE ⇒ antes/después con aceptar y descartar', (tester) async {
    await pumpAndOpen(
      tester,
      _FakeRepo(<List<CompositionJob>>[
        <CompositionJob>[_job('j3', CompositionStatus.done)],
      ]),
    );
    expect(find.text('Antes'), findsOneWidget);
    expect(find.text('Después'), findsOneWidget);
    expect(find.byKey(const Key('composition.accept.j3')), findsOneWidget);
    expect(find.byKey(const Key('composition.discard.j3')), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('aceptar OK ⇒ la hoja cierra devolviendo el ref del resultado', (
    tester,
  ) async {
    final repo = _FakeRepo(<List<CompositionJob>>[
      <CompositionJob>[_job('j3', CompositionStatus.done)],
    ]);
    await pumpAndOpen(tester, repo);
    await tester.tap(find.byKey(const Key('composition.accept.j3')));
    await tester.pumpAndSettle();
    expect(repo.accepted, <String>['j3']);
    expect(closed, isTrue);
    expect(popped, 'ref/out.png');
  });

  testWidgets('conflicto al aceptar ⇒ copy visible y la hoja sigue abierta', (
    tester,
  ) async {
    final repo =
        _FakeRepo(<List<CompositionJob>>[
            <CompositionJob>[_job('j3', CompositionStatus.done)],
          ])
          ..acceptFailure = const CompositionRejectedFailure(
            'La imagen ya no está en la galería.',
          );
    await pumpAndOpen(tester, repo);
    await tester.tap(find.byKey(const Key('composition.accept.j3')));
    await tester.pumpAndSettle();
    expect(find.text('La imagen ya no está en la galería.'), findsOneWidget);
    expect(closed, isFalse);
    await dispose(tester);
  });

  testWidgets('descartar OK ⇒ la lista se recarga sin el job', (tester) async {
    final repo = _FakeRepo(<List<CompositionJob>>[
      <CompositionJob>[_job('j3', CompositionStatus.done)],
      <CompositionJob>[],
    ]);
    await pumpAndOpen(tester, repo);
    await tester.tap(find.byKey(const Key('composition.discard.j3')));
    await tester.pumpAndSettle();
    expect(repo.discarded, <String>['j3']);
    expect(find.text('Lista'), findsNothing);
    expect(find.byKey(const Key('compose_photo.empty')), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('conflicto al descartar ⇒ copy del 409', (tester) async {
    final repo =
        _FakeRepo(<List<CompositionJob>>[
            <CompositionJob>[_job('j3', CompositionStatus.done)],
          ])
          ..discardFailure = const CompositionConflictFailure(
            'El producto usa esta imagen; cámbiala antes de descartarla.',
          );
    await pumpAndOpen(tester, repo);
    await tester.tap(find.byKey(const Key('composition.discard.j3')));
    await tester.pumpAndSettle();
    expect(
      find.text('El producto usa esta imagen; cámbiala antes de descartarla.'),
      findsOneWidget,
    );
    await dispose(tester);
  });

  testWidgets('«Elegir fondo» abre el selector y crear encola y refresca', (
    tester,
  ) async {
    final repo = _FakeRepo(<List<CompositionJob>>[
      <CompositionJob>[],
      <CompositionJob>[_job('j-nuevo', CompositionStatus.queued)],
    ]);
    await pumpAndOpen(tester, repo);
    await tester.tap(find.byKey(const Key('compose_photo.new')));
    await tester.pumpAndSettle();
    expect(find.text('Estudio blanco'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('compose_preset.create')));
    await tester.tap(find.byKey(const Key('compose_preset.create')));
    await tester.pumpAndSettle();
    expect(repo.composedPreset, 'estudio-blanco');
    expect(repo.composedPremium, isFalse);
    // El selector se cerró y el job nuevo quedó a la vista.
    expect(find.byKey(const Key('compose_preset.create')), findsNothing);
    expect(find.text('En cola'), findsOneWidget);
    await dispose(tester);
  });
}
