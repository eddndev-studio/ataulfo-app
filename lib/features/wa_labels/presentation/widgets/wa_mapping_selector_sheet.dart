import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_option_row.dart';
import '../../../labels/domain/entities/label.dart';
import '../../../labels/presentation/widgets/label_dot.dart';
import '../../domain/entities/wa_label.dart';
import '../../domain/failures/wa_labels_failure.dart';
import '../bloc/wa_label_mapping_bloc.dart';
import 'wa_label_swatch.dart';

/// Selector del Label interno al que se vincula una etiqueta WhatsApp (S21,
/// Dirección 2). Lista los Labels internos de la org; tocar uno fija el vínculo
/// (set/upsert) y "Quitar vínculo" lo borra. NO empuja a WhatsApp.
///
/// Despacha sobre el `WaLabelMappingBloc` del scope; refleja el resultado
/// (spinner mientras está en vuelo, copy de error si falla, cierre al éxito).
class WaMappingSelectorSheet extends StatefulWidget {
  const WaMappingSelectorSheet({super.key, required this.waLabel});

  final WaLabel waLabel;

  static void open(BuildContext context, WaLabel waLabel) {
    final bloc = context.read<WaLabelMappingBloc>();
    showAppBottomSheet<void>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<WaLabelMappingBloc>.value(
        value: bloc,
        child: WaMappingSelectorSheet(waLabel: waLabel),
      ),
    );
  }

  @override
  State<WaMappingSelectorSheet> createState() => _WaMappingSelectorSheetState();
}

class _WaMappingSelectorSheetState extends State<WaMappingSelectorSheet> {
  bool _didSubmit = false;

  void _set(String labelId) {
    _didSubmit = true;
    context.read<WaLabelMappingBloc>().add(
      WaMappingSetRequested(
        waLabelId: widget.waLabel.waLabelId,
        labelId: labelId,
      ),
    );
  }

  void _clear() {
    _didSubmit = true;
    context.read<WaLabelMappingBloc>().add(
      WaMappingClearRequested(waLabelId: widget.waLabel.waLabelId),
    );
  }

  static WaMappingData? _dataOf(WaMappingState s) => switch (s) {
    WaMappingLoaded(data: final d) => d,
    WaMappingMutating(data: final d) => d,
    WaMappingMutationFailed(data: final d) => d,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocListener<WaLabelMappingBloc, WaMappingState>(
      listener: (context, state) {
        if (_didSubmit && state is WaMappingLoaded) {
          Navigator.of(context).maybePop();
        }
      },
      child: BlocBuilder<WaLabelMappingBloc, WaMappingState>(
        builder: (context, state) {
          final data = _dataOf(state);
          final isMutating = state is WaMappingMutating;
          // Solo muestra el error si ESTE sheet disparó la mutación: al reabrir
          // sobre un bloc que quedó en MutationFailed (page-scoped), un sheet
          // nuevo no debe arrastrar el error de una acción anterior.
          final failure = _didSubmit && state is WaMappingMutationFailed
              ? state.failure
              : null;
          final currentId = data?.mappings[widget.waLabel.waLabelId];
          // Oculta los labels ya vinculados a otra etiqueta WhatsApp del bot
          // (exclusividad 1:1): solo ofrece lo que el server aceptaría, así el
          // operador no choca el 409. El vínculo de ESTA etiqueta se conserva.
          final selectable =
              data?.selectableLabelsFor(widget.waLabel.waLabelId) ??
              const <Label>[];
          final hasAnyInternal = data != null && data.internalLabels.isNotEmpty;
          return SingleChildScrollView(
            key: const Key('wa_mapping_selector'),
            padding: EdgeInsets.fromLTRB(
              AppTokens.sp6,
              AppTokens.sp6,
              AppTokens.sp6,
              AppTokens.sp6 + context.sheetBottomInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    WaLabelSwatch(colorIndex: widget.waLabel.color, size: 20),
                    const SizedBox(width: AppTokens.sp3),
                    Expanded(
                      child: Text(
                        'Vincular "${widget.waLabel.name}"',
                        style: textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.sp2),
                Text(
                  'Vincular esta etiqueta a un Label interno solo decide qué '
                  'automatización dispara. No cambia nada en WhatsApp.',
                  style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
                ),
                const SizedBox(height: AppTokens.sp4),
                if (selectable.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTokens.sp4,
                    ),
                    child: Text(
                      hasAnyInternal
                          ? 'Todas tus etiquetas internas ya están vinculadas '
                                'a otras etiquetas de WhatsApp.'
                          : 'No tienes etiquetas internas todavía. Créalas en '
                                'la sección Etiquetas para poder vincularlas.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTokens.text2,
                      ),
                    ),
                  )
                else
                  ...selectable.map(
                    (l) => _LabelOption(
                      label: l,
                      selected: l.id == currentId,
                      enabled: !isMutating,
                      onTap: () => _set(l.id),
                    ),
                  ),
                if (failure != null) ...<Widget>[
                  const SizedBox(height: AppTokens.sp3),
                  Text(
                    _failureMessage(failure),
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTokens.danger,
                    ),
                  ),
                ],
                if (currentId != null) ...<Widget>[
                  const SizedBox(height: AppTokens.sp3),
                  TextButton.icon(
                    key: const Key('wa_mapping_selector.remove'),
                    onPressed: isMutating ? null : _clear,
                    icon: const Icon(Icons.link_off, color: AppTokens.danger),
                    label: const Text(
                      'Quitar vínculo',
                      style: TextStyle(color: AppTokens.danger),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static String _failureMessage(WaLabelsFailure f) => switch (f) {
    WaLabelsInvalidFailure() =>
      'Esa etiqueta interna ya no existe. Actualiza la lista e inténtalo.',
    WaLabelsForbiddenFailure() =>
      'No tienes permiso para vincular etiquetas en este bot.',
    WaLabelsNotFoundFailure() => 'Este bot ya no existe en tu organización.',
    WaLabelsNetworkFailure() || WaLabelsTimeoutFailure() =>
      'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    _ => 'No pudimos guardar el vínculo. Inténtalo de nuevo.',
  };
}

class _LabelOption extends StatelessWidget {
  const _LabelOption({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Label label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppOptionRow(
      leading: LabelDot(hex: label.color, size: 18),
      title: label.name,
      selected: selected,
      onTap: enabled ? onTap : null,
    );
  }
}
