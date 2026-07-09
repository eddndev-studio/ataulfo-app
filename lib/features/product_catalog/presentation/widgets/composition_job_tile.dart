import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_media_thumb.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/composition_job.dart';
import '../compose_presets.dart';

/// Tarjeta de un job de composición: escena + chip de estado; un FAILED
/// muestra su nota, y un DONE la comparación antes/después con «Usar esta
/// foto» y «Descartar». Las miniaturas son best-effort por ref BARE (un miss
/// cae al glifo del kit).
class CompositionJobTile extends StatelessWidget {
  const CompositionJobTile({
    super.key,
    required this.job,
    required this.beforeRef,
    required this.thumbBytes,
    required this.busy,
    required this.onAccept,
    required this.onDiscard,
  });

  final CompositionJob job;

  /// Ref de la foto ACTUAL del producto (el «antes»).
  final String beforeRef;

  final AppMediaThumbLoader thumbBytes;

  /// Una mutación del flujo está en vuelo: se congelan las acciones.
  final bool busy;

  final VoidCallback onAccept;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  composePresetLabel(job.preset),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: AppTokens.sp2),
              _statusPill(job.status),
            ],
          ),
          if (job.status == CompositionStatus.failed &&
              job.errorNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppTokens.sp2),
            Text(
              job.errorNote,
              style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
            ),
          ],
          if (job.status == CompositionStatus.done) ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            Row(
              children: <Widget>[
                _Thumb(label: 'Antes', mediaRef: beforeRef, load: thumbBytes),
                const SizedBox(width: AppTokens.sp4),
                _Thumb(
                  label: 'Después',
                  mediaRef: job.resultMediaRef,
                  load: thumbBytes,
                ),
              ],
            ),
            const SizedBox(height: AppTokens.sp4),
            Row(
              children: <Widget>[
                AppButton.filled(
                  key: Key('composition.accept.${job.id}'),
                  label: 'Usar esta foto',
                  onPressed: busy ? null : onAccept,
                ),
                const SizedBox(width: AppTokens.sp2),
                AppButton.text(
                  key: Key('composition.discard.${job.id}'),
                  label: 'Descartar',
                  onPressed: busy ? null : onDiscard,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// QUEUED/RUNNING son espera (dot atenuado/vivo); DONE invita a decidir;
  /// FAILED alerta.
  static AppPill _statusPill(CompositionStatus status) => switch (status) {
    CompositionStatus.queued => const AppPill.neutral(
      label: 'En cola',
      dot: AppPillDot.paused,
    ),
    CompositionStatus.running => const AppPill.neutral(
      label: 'Creando…',
      dot: AppPillDot.active,
    ),
    CompositionStatus.done => const AppPill.primary(label: 'Lista'),
    CompositionStatus.failed => const AppPill.danger(label: 'Falló'),
  };
}

/// Miniatura rotulada de la comparación. El tamaño fijo mantiene el layout
/// estable aunque falten bytes.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.label,
    required this.mediaRef,
    required this.load,
  });

  final String label;
  final String mediaRef;
  final AppMediaThumbLoader load;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        AppMediaThumb(
          mediaRef: mediaRef,
          loader: load,
          kind: AppMediaKind.image,
          size: 96,
        ),
        const SizedBox(height: AppTokens.sp2),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
        ),
      ],
    );
  }
}
