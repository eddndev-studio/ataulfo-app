import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../conversations/domain/entities/conversation.dart';
import '../../domain/entities/wa_label.dart';
import '../../domain/failures/wa_labels_failure.dart';
import '../../domain/repositories/wa_labels_repository.dart';
import '../bloc/wa_chat_labels_bloc.dart';
import 'wa_label_swatch.dart';

/// Sheet de etiquetas WhatsApp de un chat (S21). Lista el catálogo activo del
/// bot con un check por etiqueta asociada a ESTE chat; tocar una asocia/desasocia
/// (empuja a WhatsApp vía `labelChat`). Se actualiza en vivo por SSE CHAT.
///
/// Crea su propio `WaChatLabelsBloc` leyendo el `WaLabelsRepository` del scope
/// (lo provee la ruta de conversaciones). El `kind` lo aporta la conversación.
class WaChatLabelsSheet extends StatelessWidget {
  const WaChatLabelsSheet({super.key});

  static void open(
    BuildContext context, {
    required String botId,
    required String chatLid,
    required ConversationKind kind,
  }) {
    final repo = context.read<WaLabelsRepository>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<WaChatLabelsBloc>(
        create: (_) => WaChatLabelsBloc(
          repo: repo,
          botId: botId,
          chatLid: chatLid,
          kind: kind,
        )..add(const WaChatLabelsLoadRequested()),
        child: const WaChatLabelsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WaChatLabelsBloc, WaChatLabelsState>(
      builder: (context, state) => switch (state) {
        WaChatLabelsLoading() => const _LoadingView(),
        WaChatLabelsLoaded(:final catalog, :final associated) => _Body(
          catalog: catalog,
          associated: associated,
          isMutating: false,
          failure: null,
        ),
        WaChatLabelsMutating(:final catalog, :final associated) => _Body(
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
          _Body(
            catalog: catalog,
            associated: associated,
            isMutating: false,
            failure: failure,
          ),
        WaChatLabelsFailed(:final failure) => _FailedView(failure: failure),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppTokens.sp8),
    child: Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
      ),
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body({
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
    return SingleChildScrollView(
      key: const Key('wa_chat_labels'),
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
              Expanded(
                child: Text(
                  'Etiquetas en este chat',
                  style: textTheme.titleLarge,
                ),
              ),
              // Mientras el toggle empuja a WhatsApp (puede tardar por la red),
              // un spinner sutil da feedback; los checkboxes quedan deshabilitados.
              if (isMutating)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTokens.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.sp4),
          if (catalog.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.sp4),
              child: Text(
                'No hay etiquetas de WhatsApp todavía. Créalas en la sección de '
                'etiquetas del bot.',
                style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              ),
            )
          else
            ...catalog.map(
              (l) => _LabelToggle(
                label: l,
                associated: associated.contains(l.waLabelId),
                enabled: !isMutating,
              ),
            ),
          if (failure != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp3),
            Text(
              _failureMessage(failure!),
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
            ),
          ],
        ],
      ),
    );
  }

  static String _failureMessage(WaLabelsFailure f) => switch (f) {
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

class _LabelToggle extends StatelessWidget {
  const _LabelToggle({
    required this.label,
    required this.associated,
    required this.enabled,
  });

  final WaLabel label;
  final bool associated;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: enabled
          ? () => context.read<WaChatLabelsBloc>().add(
              WaChatLabelsToggleRequested(
                waLabelId: label.waLabelId,
                associate: !associated,
              ),
            )
          : null,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp3),
        child: Row(
          children: <Widget>[
            WaLabelSwatch(colorIndex: label.color, size: 18),
            const SizedBox(width: AppTokens.sp3),
            Expanded(
              child: Text(
                label.name,
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

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final WaLabelsFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('wa_chat_labels.error'),
      padding: const EdgeInsets.all(AppTokens.sp6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'No pudimos cargar las etiquetas de este chat.',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTokens.sp3),
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
