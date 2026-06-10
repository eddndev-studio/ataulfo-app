import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../labels/domain/entities/label.dart';
import '../../../labels/presentation/widgets/label_dot.dart';
import '../../domain/entities/wa_label.dart';
import '../bloc/wa_label_mapping_bloc.dart';
import '../widgets/wa_label_swatch.dart';
import '../widgets/wa_mapping_selector_sheet.dart';

/// Pantalla de mapeo etiqueta-WhatsApp ↔ Label interno (S21, Dirección 2).
/// Consume el `WaLabelMappingBloc` del scope. Lista las etiquetas WhatsApp
/// activas con su vínculo actual (o "Sin vincular"); tocar una abre el selector.
///
/// Deja explícito que vincular NO empuja nada a WhatsApp: es lo que convierte
/// "etiqueté el chat en WhatsApp" en una automatización (dispara el trigger
/// LABEL del flujo del Label interno vinculado).
class WaLabelMappingPage extends StatelessWidget {
  const WaLabelMappingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WaLabelMappingBloc, WaMappingState>(
      builder: (context, state) {
        final data = switch (state) {
          WaMappingLoaded(data: final d) => d,
          WaMappingMutating(data: final d) => d,
          WaMappingMutationFailed(data: final d) => d,
          _ => null,
        };
        if (data != null) {
          return _LoadedView(data: data);
        }
        return switch (state) {
          WaMappingFailed(error: final e) => _FailedView(error: e),
          _ => const _LoadingView(),
        };
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.data});

  final WaMappingData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final waLabels = data.waLabels;
    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<WaLabelMappingBloc>();
        bloc.add(const WaMappingLoadRequested());
        await bloc.stream.firstWhere(
          (s) => s is WaMappingLoaded || s is WaMappingFailed,
          orElse: () => bloc.state,
        );
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp4,
          AppTokens.sp4,
          AppTokens.sp4,
          AppTokens.sp4 + context.safeBottomInset,
        ),
        children: <Widget>[
          Text(
            'Vincular una etiqueta de WhatsApp a un Label interno no la cambia en '
            'WhatsApp: solo decide qué automatización dispara cuando etiquetas un '
            'chat.',
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp4),
          if (waLabels.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.sp6),
              child: Text(
                'No hay etiquetas de WhatsApp todavía. Créalas en la sección de '
                'etiquetas para poder vincularlas.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              ),
            )
          else
            for (final wa in waLabels) ...<Widget>[
              _MappingRow(
                waLabel: wa,
                hasMapping: data.mappings.containsKey(wa.waLabelId),
                mapped: data.mappedLabel(wa.waLabelId),
              ),
              const SizedBox(height: AppTokens.cardGap),
            ],
        ],
      ),
    );
  }
}

/// Una fila: etiqueta WhatsApp (swatch + nombre) y su vínculo interno actual.
class _MappingRow extends StatelessWidget {
  const _MappingRow({
    required this.waLabel,
    required this.hasMapping,
    required this.mapped,
  });

  final WaLabel waLabel;

  /// Hay una fila de mapeo para esta etiqueta (aunque apunte a un Label borrado).
  final bool hasMapping;

  /// El Label interno vinculado RESUELTO, o `null` si no hay vínculo o si el
  /// vínculo está roto (apunta a un Label que ya no existe en la org).
  final Label? mapped;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final m = mapped;
    // onTap nativo del AppCard: ripple/highlight del InkWell interno
    // (el GestureDetector externo dejaba el tap sin feedback visual).
    return AppCard(
      onTap: () => WaMappingSelectorSheet.open(context, waLabel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              WaLabelSwatch(colorIndex: waLabel.color, size: 20),
              const SizedBox(width: AppTokens.sp3),
              Expanded(
                child: Text(
                  waLabel.name,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTokens.text2, size: 20),
            ],
          ),
          const SizedBox(height: AppTokens.sp2),
          if (m == null && !hasMapping)
            Text(
              'Sin vincular',
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            )
          else if (m == null)
            // Hay un mapeo pero el Label interno fue borrado de la org: roto.
            // El operador puede tocar la fila y "Quitar vínculo" para limpiarlo.
            Text(
              'Vínculo roto',
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.warning),
            )
          else
            Row(
              children: <Widget>[
                const Icon(Icons.link, color: AppTokens.text2, size: 16),
                const SizedBox(width: AppTokens.sp2),
                LabelDot(hex: m.color, size: 14),
                const SizedBox(width: AppTokens.sp2),
                Flexible(
                  child: Text(
                    m.name,
                    style: textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.error});

  final WaMappingError error;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('wa_mapping.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _message(error),
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<WaLabelMappingBloc>().add(
                const WaMappingLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _message(WaMappingError e) => switch (e) {
    WaMappingError.forbidden =>
      'No tienes permiso para ver los vínculos de este bot.',
    WaMappingError.notFound => 'Este bot ya no existe en tu organización.',
    WaMappingError.network =>
      'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    WaMappingError.generic => 'No pudimos cargar los vínculos.',
  };
}
