import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../domain/entities/wa_label.dart';
import '../../domain/failures/wa_labels_failure.dart';
import '../bloc/wa_chat_labels_bloc.dart';
import 'wa_label_swatch.dart';

/// Sección de etiquetas WhatsApp de un chat: el catálogo activo del bot con un
/// check por etiqueta asociada a ESTE chat; tocar una asocia/desasocia
/// (empuja a WhatsApp vía `labelChat`) y refleja en vivo por SSE. Sin chrome de
/// hoja propia: se incrusta en `ChatLabelsSheet` junto a la sección de etiquetas
/// internas. Consume el `WaChatLabelsBloc` del scope.
class WaChatLabelsSection extends StatelessWidget {
  const WaChatLabelsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WaChatLabelsBloc, WaChatLabelsState>(
      builder: (context, state) => switch (state) {
        WaChatLabelsLoading() => const _Loader(),
        WaChatLabelsLoaded(:final catalog, :final associated) => _List(
          catalog: catalog,
          associated: associated,
          isMutating: false,
          failure: null,
        ),
        WaChatLabelsMutating(:final catalog, :final associated) => _List(
          catalog: catalog,
          associated: associated,
          isMutating: true,
          failure: null,
        ),
        WaChatLabelsMutationFailed(
          :final catalog,
          :final associated,
          :final failure,
        ) =>
          _List(
            catalog: catalog,
            associated: associated,
            isMutating: false,
            failure: failure,
          ),
        WaChatLabelsFailed(:final failure) => _Error(failure: failure),
      },
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppTokens.sp4),
    child: Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
        ),
      ),
    ),
  );
}

class _List extends StatelessWidget {
  const _List({
    required this.catalog,
    required this.associated,
    required this.isMutating,
    required this.failure,
  });

  final List<WaLabel> catalog;
  final Set<String> associated;
  final bool isMutating;
  final WaLabelsFailure? failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (catalog.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.sp3),
            child: Text(
              'No hay etiquetas de WhatsApp todavía.',
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
          )
        else
          for (final l in catalog)
            _Toggle(
              waLabelId: l.waLabelId,
              name: l.name,
              colorIndex: l.color,
              associated: associated.contains(l.waLabelId),
              enabled: !isMutating,
            ),
        if (failure != null) ...<Widget>[
          const SizedBox(height: AppTokens.sp2),
          Text(
            _message(failure!),
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
          ),
        ],
      ],
    );
  }

  static String _message(WaLabelsFailure f) => switch (f) {
    WaLabelsNotConnectedFailure() =>
      'El bot no está conectado a WhatsApp. Conéctalo e inténtalo de nuevo.',
    WaLabelsUpstreamFailure() =>
      'WhatsApp no respondió. Inténtalo de nuevo en un momento.',
    WaLabelsForbiddenFailure() =>
      'No tienes permiso para etiquetar chats en este bot.',
    WaLabelsNotFoundFailure() => 'Este bot ya no existe en tu organización.',
    WaLabelsNetworkFailure() || WaLabelsTimeoutFailure() =>
      'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    _ => 'No pudimos cambiar la etiqueta. Inténtalo de nuevo.',
  };
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.waLabelId,
    required this.name,
    required this.colorIndex,
    required this.associated,
    required this.enabled,
  });

  final String waLabelId;
  final String name;
  final int colorIndex;
  final bool associated;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: enabled
          ? () => context.read<WaChatLabelsBloc>().add(
              WaChatLabelsToggleRequested(
                waLabelId: waLabelId,
                associate: !associated,
              ),
            )
          : null,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp3),
        child: Row(
          children: <Widget>[
            WaLabelSwatch(colorIndex: colorIndex, size: 18),
            const SizedBox(width: AppTokens.sp3),
            Expanded(
              child: Text(
                name,
                style: textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              associated ? Icons.check_box : Icons.check_box_outline_blank,
              color: associated ? AppTokens.primary : AppTokens.text2,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.failure});

  final WaLabelsFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('wa_chat_labels.error'),
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'No pudimos cargar las etiquetas de WhatsApp de este chat.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppTokens.sp2),
          AppButton.tonal(
            label: 'Reintentar',
            onPressed: () => context.read<WaChatLabelsBloc>().add(
              const WaChatLabelsLoadRequested(),
            ),
          ),
        ],
      ),
    );
  }
}
