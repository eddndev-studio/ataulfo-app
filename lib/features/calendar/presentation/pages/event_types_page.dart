import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_switch.dart';
import '../../domain/entities/event_type.dart';
import '../bloc/event_types_cubit.dart';
import '../calendar_format.dart';
import '../widgets/event_type_form_sheet.dart';

/// Ajustes → Agenda → Tipos de cita: lista con crear/editar y toggle de
/// activo. Página de una pushed route (aporta Scaffold+AppBar). Consume el
/// `EventTypesCubit` del scope de la ruta.
class EventTypesPage extends StatelessWidget {
  const EventTypesPage({super.key});

  Future<void> _openCreate(BuildContext context) {
    final cubit = context.read<EventTypesCubit>();
    return EventTypeFormSheet.open(
      context,
      onSubmit:
          ({
            required String name,
            required String description,
            required int durationMin,
            required bool active,
          }) => cubit.create(
            name: name,
            description: description,
            durationMin: durationMin,
          ),
    );
  }

  Future<void> _openEdit(BuildContext context, EventType et) {
    final cubit = context.read<EventTypesCubit>();
    return EventTypeFormSheet.open(
      context,
      initial: et,
      onSubmit:
          ({
            required String name,
            required String description,
            required int durationMin,
            required bool active,
          }) => cubit.update(
            id: et.id,
            name: name,
            description: description,
            durationMin: durationMin,
            active: active,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EventTypesCubit, EventTypesState>(
      builder: (context, state) {
        return switch (state.status) {
          EventTypesStatus.loading => const Center(
            child: AppLoadingIndicator(),
          ),
          EventTypesStatus.error => AppErrorState(
            message: 'No se pudieron cargar los tipos de cita.',
            onRetry: () => context.read<EventTypesCubit>().load(),
          ),
          EventTypesStatus.loaded => _Loaded(
            items: state.items,
            onCreate: () => _openCreate(context),
            onEdit: (et) => _openEdit(context, et),
          ),
        };
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.items,
    required this.onCreate,
    required this.onEdit,
  });

  final List<EventType> items;
  final VoidCallback onCreate;
  final ValueChanged<EventType> onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp5,
        AppTokens.sp5,
        AppTokens.sp5,
        AppTokens.sp5 + context.safeBottomInset,
      ),
      children: <Widget>[
        AppButton.tonal(
          key: const Key('event_types.create'),
          label: 'Nuevo tipo de cita',
          icon: Icons.add,
          fullWidth: true,
          onPressed: onCreate,
        ),
        const SizedBox(height: AppTokens.sp5),
        if (items.isEmpty)
          const AppEmptyState(
            key: Key('event_types.empty'),
            icon: Icons.event_note_outlined,
            title: 'Aún no hay tipos de cita',
            description:
                'Crea el primer tipo (nombre y duración) para que tú y el '
                'asistente puedan reservar citas.',
          )
        else
          AppCard(
            child: Column(
              children: <Widget>[
                for (var i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0)
                    const Divider(
                      height: AppTokens.sp5,
                      color: AppTokens.divider,
                    ),
                  _EventTypeRow(
                    eventType: items[i],
                    onTap: () => onEdit(items[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _EventTypeRow extends StatelessWidget {
  const _EventTypeRow({required this.eventType, required this.onTap});

  final EventType eventType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final et = eventType;
    final dim = et.active ? 1.0 : 0.5;
    return InkWell(
      key: Key('event_types.row.${et.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp2),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Opacity(
                opacity: dim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      et.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${durationLabel(et.durationMin)}'
                      '${et.active ? '' : ' · inactivo'}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTokens.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppTokens.sp3),
            // Toggle rápido de activo sin abrir el formulario.
            AppSwitch(
              value: et.active,
              onChanged: (v) =>
                  context.read<EventTypesCubit>().setActive(et, v),
            ),
          ],
        ),
      ),
    );
  }
}
