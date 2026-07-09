import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_media_thumb.dart';
import '../../domain/entities/composition_job.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/composition_repository.dart';
import '../bloc/composition_cubit.dart';
import '../composition_copy.dart';
import 'compose_preset_sheet.dart';
import 'composition_job_tile.dart';

/// Hoja «Mejorar foto con IA» de un producto: sus composiciones con estado
/// vivo (el cubit polea mientras haya jobs en vuelo) y el CTA para encolar
/// una nueva. Se cierra devolviendo el ref del resultado ACEPTADO (la foto
/// nueva del producto) o null si el operador solo miró.
class ComposePhotoSheet extends StatefulWidget {
  const ComposePhotoSheet({
    super.key,
    required this.product,
    required this.thumbBytes,
  });

  final Product product;

  /// Resuelve los bytes de una miniatura por ref BARE (antes y después);
  /// null ⇒ glifo del kit. La firma es la del kit: quién descarga y cachea
  /// es del wiring, no de esta hoja.
  final AppMediaThumbLoader thumbBytes;

  static Future<String?> open(
    BuildContext context, {
    required Product product,
    required CompositionRepository repo,
    required AppMediaThumbLoader thumbBytes,
    Duration pollInterval = const Duration(seconds: 4),
  }) => showAppBottomSheet<String>(
    context,
    backgroundColor: AppTokens.surface1,
    isScrollControlled: true,
    builder: (_) => BlocProvider<CompositionCubit>(
      create: (_) => CompositionCubit(
        repo,
        productId: product.id,
        pollInterval: pollInterval,
      )..load(),
      child: ComposePhotoSheet(product: product, thumbBytes: thumbBytes),
    ),
  );

  @override
  State<ComposePhotoSheet> createState() => _ComposePhotoSheetState();
}

class _ComposePhotoSheetState extends State<ComposePhotoSheet> {
  String? _error;

  Future<void> _openPresets() async {
    final cubit = context.read<CompositionCubit>();
    setState(() => _error = null);
    await ComposePresetSheet.open(
      context,
      onCreate: ({required String preset, required bool premium}) =>
          cubit.compose(preset: preset, premium: premium),
    );
  }

  Future<void> _accept(CompositionJob job) async {
    final failure = await context.read<CompositionCubit>().accept(job.id);
    if (!mounted) return;
    if (failure == null) {
      // El resultado YA es la foto del producto: la hoja entrega el ref
      // nuevo a quien la abrió (el formulario lo refleja al instante).
      Navigator.of(context).pop(job.resultMediaRef);
      return;
    }
    setState(() => _error = compositionErrorText(failure));
  }

  Future<void> _discard(CompositionJob job) async {
    final failure = await context.read<CompositionCubit>().discard(job.id);
    if (!mounted) return;
    setState(
      () => _error = failure == null ? null : compositionErrorText(failure),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp5,
          AppTokens.sp2,
          AppTokens.sp5,
          AppTokens.sp5 + context.safeBottomInset,
        ),
        child: SingleChildScrollView(
          child: BlocBuilder<CompositionCubit, CompositionState>(
            builder: (context, state) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Mejorar foto con IA', style: textTheme.titleLarge),
                const SizedBox(height: AppTokens.sp2),
                Text(
                  widget.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
                ),
                const SizedBox(height: AppTokens.sp4),
                AppButton.tonal(
                  key: const Key('compose_photo.new'),
                  label: 'Elegir fondo',
                  icon: Icons.auto_awesome_outlined,
                  onPressed: state.mutating ? null : _openPresets,
                ),
                const SizedBox(height: AppTokens.sp4),
                ..._body(state),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: AppTokens.sp3),
                  Text(
                    _error!,
                    key: const Key('compose_photo.error'),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTokens.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(CompositionState state) => switch (state.status) {
    CompositionListStatus.loading => const <Widget>[
      Padding(
        padding: EdgeInsets.symmetric(vertical: AppTokens.sp6),
        child: Center(child: AppLoadingIndicator()),
      ),
    ],
    CompositionListStatus.error => <Widget>[
      AppErrorState(
        message: 'No se pudieron cargar las composiciones.',
        onRetry: () => context.read<CompositionCubit>().load(),
      ),
    ],
    CompositionListStatus.loaded when state.jobs.isEmpty => <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp4),
        child: Text(
          'Aún no hay fondos creados para este producto. '
          'Elige uno para empezar.',
          key: const Key('compose_photo.empty'),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTokens.text2),
        ),
      ),
    ],
    CompositionListStatus.loaded => <Widget>[
      for (final job in state.jobs) ...<Widget>[
        CompositionJobTile(
          job: job,
          beforeRef: widget.product.mediaRef,
          thumbBytes: widget.thumbBytes,
          busy: state.mutating,
          onAccept: () => _accept(job),
          onDiscard: () => _discard(job),
        ),
        const SizedBox(height: AppTokens.sp3),
      ],
    ],
  };
}
