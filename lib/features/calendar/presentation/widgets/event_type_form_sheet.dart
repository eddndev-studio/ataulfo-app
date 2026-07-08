import 'package:flutter/material.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_switch.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/event_type.dart';
import '../../domain/failures/calendar_failure.dart';

/// Duraciones ofrecidas para un tipo de evento (múltiplos de 15 min). El
/// backend acepta cualquier múltiplo de 15; el formulario ofrece los usuales.
const List<int> kEventDurations = <int>[15, 30, 45, 60, 90, 120];

/// Formulario de crear/editar un tipo de evento como hoja inferior. En alta
/// [initial] es null (nace activo, sin toggle); en edición trae el tipo y
/// muestra el toggle «Activo». [onSubmit] persiste y devuelve la falla o null.
class EventTypeFormSheet extends StatefulWidget {
  const EventTypeFormSheet({super.key, this.initial, required this.onSubmit});

  final EventType? initial;
  final Future<CalendarFailure?> Function({
    required String name,
    required String description,
    required int durationMin,
    required bool active,
  })
  onSubmit;

  static Future<void> open(
    BuildContext context, {
    EventType? initial,
    required Future<CalendarFailure?> Function({
      required String name,
      required String description,
      required int durationMin,
      required bool active,
    })
    onSubmit,
  }) => showAppBottomSheet<void>(
    context,
    backgroundColor: AppTokens.surface1,
    isScrollControlled: true,
    builder: (_) => EventTypeFormSheet(initial: initial, onSubmit: onSubmit),
  );

  @override
  State<EventTypeFormSheet> createState() => _EventTypeFormSheetState();
}

class _EventTypeFormSheetState extends State<EventTypeFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late int _duration;
  late bool _active;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final it = widget.initial;
    _nameCtrl = TextEditingController(text: it?.name ?? '');
    _descCtrl = TextEditingController(text: it?.description ?? '');
    _duration = it?.durationMin ?? 30;
    _active = it?.active ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _busy) {
      setState(() => _error = 'Ponle un nombre al tipo de cita.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await widget.onSubmit(
      name: name,
      description: _descCtrl.text.trim(),
      durationMin: _duration,
      active: _active,
    );
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = _messageFor(failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final durations = <int>{...kEventDurations, _duration}.toList()..sort();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp5,
          AppTokens.sp2,
          AppTokens.sp5,
          AppTokens.sp5 + context.safeBottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _isEdit ? 'Editar tipo de cita' : 'Nuevo tipo de cita',
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: AppTokens.sp5),
              AppTextField(
                key: const Key('event_type.name'),
                label: 'Nombre',
                hint: 'Ej. Consulta inicial',
                controller: _nameCtrl,
                autofocus: !_isEdit,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppTokens.sp4),
              AppTextField(
                key: const Key('event_type.description'),
                label: 'Descripción (opcional)',
                hint: 'Qué incluye, para qué es…',
                controller: _descCtrl,
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: AppTokens.sp5),
              Text('Duración', style: textTheme.titleMedium),
              const SizedBox(height: AppTokens.sp3),
              Wrap(
                spacing: AppTokens.sp2,
                runSpacing: AppTokens.sp2,
                children: <Widget>[
                  for (final d in durations)
                    AppChoiceChip(
                      key: Key('event_type.duration.$d'),
                      label: _durationLabel(d),
                      selected: _duration == d,
                      onSelected: (_) => setState(() => _duration = d),
                    ),
                ],
              ),
              if (_isEdit) ...<Widget>[
                const SizedBox(height: AppTokens.sp5),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Activo', style: textTheme.bodyLarge),
                          Text(
                            'Los tipos inactivos no se ofrecen para reservar.',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppTokens.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSwitch(
                      key: const Key('event_type.active'),
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                    ),
                  ],
                ),
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppTokens.sp3),
                Text(
                  _error!,
                  key: const Key('event_type.error'),
                  style: textTheme.bodySmall?.copyWith(color: AppTokens.danger),
                ),
              ],
              const SizedBox(height: AppTokens.sp5),
              AppButton.filled(
                key: const Key('event_type.save'),
                label: _isEdit ? 'Guardar cambios' : 'Crear tipo',
                fullWidth: true,
                loading: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _durationLabel(int min) {
    if (min < 60) return '$min min';
    final h = min ~/ 60;
    final rem = min % 60;
    return rem == 0 ? '$h h' : '$h h $rem min';
  }

  String _messageFor(CalendarFailure failure) => switch (failure) {
    CalendarValidationFailure(:final message) =>
      message ?? 'Revisa los datos e inténtalo otra vez.',
    CalendarForbiddenFailure() => 'No tienes permiso para esta acción.',
    CalendarNetworkFailure() =>
      'Sin conexión. Revisa tu red e inténtalo otra vez.',
    CalendarTimeoutFailure() =>
      'La operación tardó demasiado. Inténtalo otra vez.',
    _ => 'No se pudo guardar. Inténtalo otra vez.',
  };
}
