import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_dot_label.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_swatch_icon.dart';
import '../../../labels/domain/entities/label.dart';
import '../../domain/entities/wa_label.dart';
import '../bloc/wa_label_mapping_bloc.dart';
import '../widgets/wa_label_palette.dart';
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

  /// Etiquetas con vínculo RESUELTO (un mapeo roto no automatiza nada: no
  /// cuenta como vinculada).
  int get _linkedCount =>
      data.waLabels.where((w) => data.mappedLabel(w.waLabelId) != null).length;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final waLabels = data.waLabels;
    final linked = _linkedCount;
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
          if (waLabels.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            // Resumen del progreso del mapeo de un vistazo.
            Align(
              alignment: Alignment.centerLeft,
              child: AppPill.neutral(
                key: const Key('wa_mapping.summary'),
                label:
                    '$linked de ${waLabels.length} '
                    '${linked == 1 ? 'vinculada' : 'vinculadas'}',
              ),
            ),
          ],
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
            _MappingsCard(data: data),
        ],
      ),
    );
  }
}

/// El mapeo como UNA card que apila las filas separadas por divider hairline
/// (idioma de los hubs y de ajustes), en lugar de una card suelta por item.
class _MappingsCard extends StatelessWidget {
  const _MappingsCard({required this.data});

  final WaMappingData data;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < data.waLabels.length; i++) {
      if (i > 0) {
        rows.add(
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
        );
      }
      final wa = data.waLabels[i];
      rows.add(
        _MappingRow(
          waLabel: wa,
          hasMapping: data.mappings.containsKey(wa.waLabelId),
          mapped: data.mappedLabel(wa.waLabelId),
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}

/// Una fila: etiqueta WhatsApp (swatch + nombre) y su vínculo interno actual.
/// Toda la fila es tap-target hacia el selector; el InkWell propio da el
/// ripple (la card contenedora no es tappable).
///
/// El estado del vínculo habla con dos voces: el resuelto y el pendiente son
/// ambientales (se repiten por fila) y van quietos como [AppDotLabel] — verde
/// el vinculado, neutro el "Sin vincular" —; solo el vínculo roto es
/// excepcional y accionable, y conserva su pill danger.
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
    return InkWell(
      key: Key('wa_mapping.tile.${waLabel.waLabelId}'),
      onTap: () => WaMappingSelectorSheet.open(context, waLabel),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
        child: Row(
          children: <Widget>[
            // Identidad cromática de la etiqueta WA con presencia (paridad con
            // el catálogo).
            AppSwatchIcon(
              color: WaLabelPalette.resolve(waLabel.color),
              icon: Icons.sell_outlined,
            ),
            const SizedBox(width: AppTokens.sp4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    waLabel.name,
                    style: textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTokens.sp1),
                  if (m == null && !hasMapping)
                    const AppDotLabel(
                      color: AppTokens.text2,
                      label: 'Sin vincular',
                    )
                  else if (m == null)
                    // Hay un mapeo pero el Label interno fue borrado de la
                    // org: roto. El operador toca la fila y "Quitar vínculo"
                    // limpia.
                    const AppPill.danger(label: 'Vínculo roto')
                  else
                    // El dot verde dice "vinculada y sana"; el caption dice a
                    // qué label interno. El color propio del label vive en el
                    // selector, no compite aquí con la semántica del estado.
                    AppDotLabel(color: AppTokens.success, label: m.name),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.sp2),
            const Icon(Icons.chevron_right, color: AppTokens.text2, size: 20),
          ],
        ),
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
