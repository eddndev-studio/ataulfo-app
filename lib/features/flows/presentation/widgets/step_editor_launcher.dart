import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/tokens.dart';
import '../../../labels/domain/repositories/labels_repository.dart';
import '../../../labels/presentation/bloc/labels_bloc.dart';
import '../../domain/entities/step.dart' as fdom;
import '../bloc/flow_steps_bloc.dart';
import 'step_edit_sheet.dart';
import 'step_type_selector.dart';

/// Abre el editor de pasos en su forma canónica de DOS TIEMPOS: al crear,
/// primero el selector de tipo agrupado y —solo si el operador eligió—
/// el sheet de composición de ese tipo; cancelar el selector no abre nada.
/// Al editar, directo a la composición (el tipo ya existe y es inmutable).
///
/// [insertOrder] es la posición que ocupará el paso nuevo (inserción
/// posicional: el backend desplaza los siguientes); null = append. Solo
/// aplica al crear.
Future<void> openStepEditor(
  BuildContext context, {
  fdom.Step? editing,
  MediaRefPicker? pickMediaRef,
  int? insertOrder,
}) async {
  if (editing != null) {
    return showStepEditSheet(
      context,
      editing: editing,
      pickMediaRef: pickMediaRef,
    );
  }
  final type = await showStepTypeSelector(context);
  if (type == null || !context.mounted) return;
  return showStepEditSheet(
    context,
    createType: type,
    pickMediaRef: pickMediaRef,
    insertOrder: insertOrder,
  );
}

/// Monta el sheet de composición como modal canónico (surface1),
/// re-proveyendo el `FlowStepsBloc` del scope y creando un `LabelsBloc`
/// propio para el selector del paso LABEL (carga única del catálogo
/// org-scoped; si el paso no es LABEL, la carga es barata y se descarta al
/// cerrar). El guard de descarte consulta al propio sheet por cambios sin
/// guardar vía su GlobalKey; si el estado ya no existe (sheet desmontado)
/// no hay nada que proteger.
Future<void> showStepEditSheet(
  BuildContext context, {
  fdom.Step? editing,
  fdom.StepType? createType,
  MediaRefPicker? pickMediaRef,
  int? insertOrder,
}) {
  final bloc = context.read<FlowStepsBloc>();
  final labelsRepo = context.read<LabelsRepository>();
  final sheetKey = GlobalKey<StepEditSheetState>();
  return showAppBottomSheet<void>(
    context,
    isScrollControlled: true,
    backgroundColor: AppTokens.surface1,
    confirmDiscard: () => sheetKey.currentState?.shouldGuardDiscard ?? false,
    builder: (_) => MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<FlowStepsBloc>.value(value: bloc),
        BlocProvider<LabelsBloc>(
          create: (_) =>
              LabelsBloc(repo: labelsRepo)..add(const LabelsLoadRequested()),
        ),
      ],
      child: StepEditSheet(
        key: sheetKey,
        editing: editing,
        createType: createType,
        pickMediaRef: pickMediaRef,
        insertOrder: insertOrder,
      ),
    ),
  );
}
