import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/flows/domain/entities/flow.dart' as flows;
import 'package:ataulfo/features/flows/domain/entities/step.dart' as fdom;
import 'package:ataulfo/features/flows/presentation/bloc/flow_detail_bloc.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flow_steps_bloc.dart';
import 'package:ataulfo/features/flows/presentation/bloc/media_names_cubit.dart';
import 'package:ataulfo/features/flows/presentation/pages/flow_detail_page.dart';
import 'package:ataulfo/features/labels/domain/repositories/labels_repository.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/triggers/domain/entities/trigger.dart';
import 'package:ataulfo/features/triggers/domain/repositories/triggers_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDetailBloc extends MockBloc<FlowDetailEvent, FlowDetailState>
    implements FlowDetailBloc {}

class _MockStepsBloc extends MockBloc<FlowStepsEvent, FlowStepsState>
    implements FlowStepsBloc {}

class _MockMediaRepo extends Mock implements MediaRepository {}

class _MockTriggersRepo extends Mock implements TriggersRepository {}

class _MockLabelsRepo extends Mock implements LabelsRepository {}

/// Verificación de la CADENA REAL de resolución de alias (no del render con un
/// cubit sembrado, que cubren los otros tests). Aquí el `MediaNamesCubit` es
/// REAL: se construye con un repo, se dispara `load()`, pagina el catálogo,
/// arma el mapa ref→displayName, y `_StepBody` lo lee por su ref. Atrapa fallos
/// de cableado (provider fuera de scope, `load()` que no corre, lookup que no
/// pega) que un cubit mock esconde.
const _flow = flows.Flow(
  id: 'f1',
  templateId: 't1',
  name: 'Bienvenida',
  isActive: true,
  version: 1,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

const _audioRef = 'tenant/org1/media/9y1gq8fq8f68g69696wv.ogg';

void main() {
  late _MockDetailBloc detailBloc;
  late _MockStepsBloc stepsBloc;
  late _MockMediaRepo mediaRepo;
  late _MockTriggersRepo triggersRepo;
  late _MockLabelsRepo labelsRepo;

  setUp(() {
    detailBloc = _MockDetailBloc();
    stepsBloc = _MockStepsBloc();
    mediaRepo = _MockMediaRepo();
    triggersRepo = _MockTriggersRepo();
    labelsRepo = _MockLabelsRepo();

    when(() => detailBloc.state).thenReturn(
      const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
    );
    // Un paso PTT cuyo ref BARE es el id .ogg que el usuario vio. Su metadata
    // trae un media_filename distinto, para probar que el alias en vivo gana.
    when(() => stepsBloc.state).thenReturn(
      const FlowStepsLoaded(<fdom.Step>[
        fdom.Step(
          id: 's-audio',
          flowId: 'f1',
          type: fdom.StepType.ptt,
          order: 0,
          content: '',
          mediaRef: _audioRef,
          metadataJson: '{"media_filename":"grabacion-cruda.ogg"}',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
      ]),
    );
    // El catálogo: el asset con el ref del paso, aliaseado en la galería.
    when(
      () => mediaRepo.listAssets(
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
        type: any(named: 'type'),
        q: any(named: 'q'),
      ),
    ).thenAnswer(
      (_) async => MediaPage(
        assets: <MediaAsset>[
          MediaAsset(
            ref: _audioRef,
            previewUrl: null,
            filename: 'grabacion-cruda.ogg',
            alias: 'Saludo de bienvenida',
            contentType: 'audio/ogg',
            size: 1,
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ],
        nextCursor: '',
      ),
    );
    // El tab Disparadores crea su bloc lazy; lo dejamos en loading sin timers.
    when(
      () => triggersRepo.listTriggers(any()),
    ).thenAnswer((_) => Completer<List<Trigger>>().future);
  });

  // Espeja el cableado del router en `/flows/:id`: el MediaNamesCubit REAL se
  // crea con el repo y dispara load() al montar.
  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<TriggersRepository>.value(value: triggersRepo),
        RepositoryProvider<LabelsRepository>.value(value: labelsRepo),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<FlowDetailBloc>.value(value: detailBloc),
          BlocProvider<FlowStepsBloc>.value(value: stepsBloc),
          BlocProvider<MediaNamesCubit>(
            create: (_) => MediaNamesCubit(repo: mediaRepo)..load(),
          ),
        ],
        child: const Scaffold(body: FlowDetailPage()),
      ),
    ),
  );

  testWidgets(
    'cadena real: load() del catálogo resuelve el ref del paso al alias en vivo',
    (tester) async {
      await tester.pumpWidget(host());
      // Deja correr load() (la página del catálogo) y el rebuild del BlocBuilder.
      await tester.pumpAndSettle();

      expect(find.text('Saludo de bienvenida'), findsOneWidget);
      // Ni el id del ref ni el filename crudo: el alias en vivo manda.
      expect(find.textContaining('9y1gq8'), findsNothing);
      expect(find.textContaining('grabacion-cruda'), findsNothing);

      // El cubit consultó el catálogo (la cadena corrió de verdad).
      verify(
        () => mediaRepo.listAssets(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          type: any(named: 'type'),
          q: any(named: 'q'),
        ),
      ).called(greaterThanOrEqualTo(1));
    },
  );

  testWidgets(
    'cadena real: catálogo sin el ref ⇒ cae al media_filename guardado',
    (tester) async {
      // El catálogo no contiene el asset del paso (p. ej. borrado): la lista
      // cae al respaldo (media_filename), no al id crudo.
      when(
        () => mediaRepo.listAssets(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          type: any(named: 'type'),
          q: any(named: 'q'),
        ),
      ).thenAnswer(
        (_) async => const MediaPage(assets: <MediaAsset>[], nextCursor: ''),
      );

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('grabacion-cruda.ogg'), findsOneWidget);
      expect(find.textContaining('9y1gq8'), findsNothing);
    },
  );
}
