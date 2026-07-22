import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_header_card.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/util/user_greeting.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/appointment.dart';
import '../bloc/agenda_cubit.dart';
import '../calendar_format.dart';
import '../widgets/appointment_detail_sheet.dart';
import '../widgets/appointment_tile.dart';
import '../widgets/month_calendar_sheet.dart';

/// Pantalla Agenda (tab del shell): la vista de UN día con navegación de
/// fechas y la lista de citas de ese día. Content-only: el Scaffold y el FAB de
/// reserva los aporta el shell. Consume el `AgendaCubit` del scope del shell,
/// que carga el día de hoy al montarse la tab.
class AgendaPage extends StatelessWidget {
  const AgendaPage({
    super.key,
    this.onOpenSettings,
    this.onManageEventTypes,
    this.onManageBusinessHours,
  });

  /// Acción del avatar del header → abrir Ajustes (la aporta el shell).
  final VoidCallback? onOpenSettings;

  /// Gestión contextual de Agenda. El shell las aporta sólo a ADMIN+.
  final VoidCallback? onManageEventTypes;
  final VoidCallback? onManageBusinessHours;

  /// Correo del operador para el avatar/saludo del header. Solo se consulta
  /// cuando el shell aporta la navegación a Ajustes (el avatar va en pareja con
  /// su acción); en montajes aislados sin AuthBloc, el header queda solo-título.
  String _operatorEmail(BuildContext context) {
    final state = context.read<AuthBloc>().state;
    return switch (state) {
      AuthAuthenticated(:final identity) => identity.email,
      AuthAuthenticatedNoOrg(:final identity) => identity.email,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = onOpenSettings == null
        ? null
        : userGreeting(_operatorEmail(context));
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppHeaderCard(
            greeting: user?.greeting,
            title: 'Agenda',
            avatarInitial: user?.initial,
            onAvatarTap: onOpenSettings,
            watermark: Icons.event_available,
            content: _DayNavBar(
              onManageEventTypes: onManageEventTypes,
              onManageBusinessHours: onManageBusinessHours,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTokens.sp5,
              AppTokens.sp5,
              AppTokens.sp5,
              AppTokens.fabClearance + context.safeBottomInset,
            ),
            child: const _DayBody(),
          ),
        ],
      ),
    );
  }
}

/// Barra de navegación del día, embebida en el header sobre el gradiente:
/// ‹ día › con un botón de calendario para saltar a una fecha y «Hoy» cuando
/// el día en foco no es hoy.
class _DayNavBar extends StatelessWidget {
  const _DayNavBar({this.onManageEventTypes, this.onManageBusinessHours});

  final VoidCallback? onManageEventTypes;
  final VoidCallback? onManageBusinessHours;

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day == DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate(BuildContext context) async {
    final cubit = context.read<AgendaCubit>();
    final picked = await MonthCalendarSheet.open(
      context,
      initialDate: cubit.state.day,
    );
    if (picked != null) await cubit.goToDay(picked);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgendaCubit, AgendaState>(
      buildWhen: (a, b) => a.day != b.day,
      builder: (context, state) {
        final onToday = _isToday(state.day);
        return Row(
          children: <Widget>[
            _GlassIconButton(
              rowKey: const Key('agenda.prev_day'),
              icon: Icons.chevron_left,
              onTap: () => context.read<AgendaCubit>().prevDay(),
            ),
            Expanded(
              child: GestureDetector(
                key: const Key('agenda.pick_date'),
                onTap: () => _pickDate(context),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: <Widget>[
                    Text(
                      agendaDayHeader(state.day),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTokens.fontSans,
                        fontSize: AppTokens.titleMSize,
                        fontWeight: AppTokens.titleMWeight,
                        color: AppTokens.onPrimary,
                      ),
                    ),
                    if (!onToday)
                      GestureDetector(
                        key: const Key('agenda.today'),
                        onTap: () => context.read<AgendaCubit>().goToToday(),
                        child: Text(
                          'Volver a hoy',
                          style: TextStyle(
                            fontFamily: AppTokens.fontSans,
                            fontSize: AppTokens.captionSize,
                            fontWeight: AppTokens.captionWeight,
                            color: AppTokens.onPrimary.withValues(alpha: 0.8),
                            decoration: TextDecoration.underline,
                            decorationColor: AppTokens.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (onManageEventTypes != null || onManageBusinessHours != null)
              PopupMenuButton<_AgendaManageAction>(
                key: const Key('agenda.manage'),
                tooltip: 'Configurar agenda',
                icon: const Icon(Icons.tune, color: AppTokens.onPrimary),
                onSelected: (action) {
                  switch (action) {
                    case _AgendaManageAction.eventTypes:
                      onManageEventTypes?.call();
                    case _AgendaManageAction.businessHours:
                      onManageBusinessHours?.call();
                  }
                },
                itemBuilder: (_) => <PopupMenuEntry<_AgendaManageAction>>[
                  if (onManageEventTypes != null)
                    const PopupMenuItem<_AgendaManageAction>(
                      key: Key('agenda.manage.event_types'),
                      value: _AgendaManageAction.eventTypes,
                      child: Text('Tipos de cita'),
                    ),
                  if (onManageBusinessHours != null)
                    const PopupMenuItem<_AgendaManageAction>(
                      key: Key('agenda.manage.business_hours'),
                      value: _AgendaManageAction.businessHours,
                      child: Text('Horario de atención'),
                    ),
                ],
              ),
            _GlassIconButton(
              rowKey: const Key('agenda.next_day'),
              icon: Icons.chevron_right,
              onTap: () => context.read<AgendaCubit>().nextDay(),
            ),
          ],
        );
      },
    );
  }
}

enum _AgendaManageAction { eventTypes, businessHours }

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.rowKey,
    required this.icon,
    required this.onTap,
  });

  final Key rowKey;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: rowKey,
      icon: Icon(icon, color: AppTokens.onPrimary),
      onPressed: onTap,
    );
  }
}

class _DayBody extends StatelessWidget {
  const _DayBody();

  Future<void> _openDetail(BuildContext context, Appointment a) {
    final cubit = context.read<AgendaCubit>();
    return AppointmentDetailSheet.open(
      context,
      appointment: a,
      onStatusChange: (status) => cubit.setStatus(a.id, status),
      onOpenChat: a.hasChat
          ? () => context.push(
              '/bots/${a.botId}/sessions/${Uri.encodeComponent(a.chatLid!)}',
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgendaCubit, AgendaState>(
      builder: (context, state) {
        return switch (state.status) {
          AgendaStatus.loading => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTokens.sp8),
            child: AppLoadingIndicator(label: 'Cargando la agenda…'),
          ),
          AgendaStatus.error => AppErrorState(
            message: 'No se pudo cargar la agenda.',
            onRetry: () => context.read<AgendaCubit>().load(),
          ),
          AgendaStatus.loaded =>
            state.appointments.isEmpty
                ? const AppEmptyState(
                    key: Key('agenda.empty'),
                    icon: Icons.event_available_outlined,
                    title: 'Sin citas este día',
                    description:
                        'Cuando reserves una cita —tú o el asistente— aparecerá '
                        'aquí.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final a in state.appointments) ...<Widget>[
                        AppointmentTile(
                          appointment: a,
                          onTap: () => _openDetail(context, a),
                        ),
                        const SizedBox(height: AppTokens.sp3),
                      ],
                    ],
                  ),
        };
      },
    );
  }
}
