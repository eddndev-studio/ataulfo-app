import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/flow.dart' as fdom;
import '../bloc/flow_detail_bloc.dart';
import 'flow_rename_sheet.dart';

/// Snapshot de cabecera visible del [FlowDetailBloc], o `null` en los
/// estados sin flujo que mostrar (Loading / Failed / Deleted).
fdom.Flow? _flowOf(FlowDetailState state) => switch (state) {
  FlowDetailLoaded(:final flow) => flow,
  FlowDetailMutating(:final flow) => flow,
  FlowDetailMutationFailed(:final flow) => flow,
  _ => null,
};

/// Título del AppBar de `/flows/:id`: el NOMBRE del flujo — la identidad
/// siempre visible mientras se edita. Sin snapshot cae a un rótulo
/// neutro (la carga o el fallo hablan en el cuerpo).
class FlowDetailTitle extends StatelessWidget {
  const FlowDetailTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlowDetailBloc, FlowDetailState>(
      builder: (context, state) => Text(_flowOf(state)?.name ?? 'Flujo'),
    );
  }
}

/// Acciones del menú ⋮ del editor de flujo.
enum _FlowMenuAction { rename, toggleActive }

/// Menú ⋮ del AppBar de `/flows/:id`: Renombrar (form-sheet) y
/// Pausar/Activar (toggle de `isActive`, mismo PUT del contrato). Solo se
/// ofrece con snapshot — sin flujo cargado no hay nada que operar.
class FlowDetailMenuAction extends StatelessWidget {
  const FlowDetailMenuAction({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlowDetailBloc, FlowDetailState>(
      builder: (context, state) {
        final flow = _flowOf(state);
        if (flow == null) return const SizedBox.shrink();
        return PopupMenuButton<_FlowMenuAction>(
          key: const Key('flow_detail.menu'),
          tooltip: 'Más acciones',
          icon: const Icon(Icons.more_vert),
          onSelected: (action) => switch (action) {
            _FlowMenuAction.rename => FlowRenameSheet.open(context, flow),
            _FlowMenuAction.toggleActive => context.read<FlowDetailBloc>().add(
              FlowDetailSetActiveRequested(!flow.isActive),
            ),
          },
          itemBuilder: (_) => <PopupMenuEntry<_FlowMenuAction>>[
            const PopupMenuItem<_FlowMenuAction>(
              key: Key('flow_detail.menu.rename'),
              value: _FlowMenuAction.rename,
              child: Text('Renombrar'),
            ),
            PopupMenuItem<_FlowMenuAction>(
              key: const Key('flow_detail.menu.toggle_active'),
              value: _FlowMenuAction.toggleActive,
              child: Text(flow.isActive ? 'Pausar' : 'Activar'),
            ),
          ],
        );
      },
    );
  }
}
