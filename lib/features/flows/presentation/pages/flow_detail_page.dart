import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/flow.dart' as fdom;
import '../../domain/entities/step.dart' as sdom;
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_detail_bloc.dart';

/// Detalle de un Flow (S11) — read-only en F2. Render por estado del
/// `FlowDetailBloc` del scope; el cableado del provider, el AppBar y el
/// Scaffold los aporta la ruta `/flows/:id`.
class FlowDetailPage extends StatelessWidget {
  const FlowDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlowDetailBloc, FlowDetailState>(
      builder: (context, state) => switch (state) {
        FlowDetailLoading() => const _LoadingView(),
        FlowDetailLoaded(flow: final f, steps: final ss) => _LoadedView(
          flow: f,
          steps: ss,
        ),
        FlowDetailFailed(failure: final f) => _FailedView(failure: f),
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
  const _LoadedView({required this.flow, required this.steps});

  final fdom.Flow flow;
  final List<sdom.Step> steps;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final viewPaddingBottom = MediaQuery.viewPaddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6 + viewPaddingBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(flow.name, style: textTheme.titleLarge),
          const SizedBox(height: AppTokens.sp3),
          Wrap(
            spacing: AppTokens.sp2,
            runSpacing: AppTokens.sp2,
            children: <Widget>[
              AppPill.outline(label: 'v${flow.version}'),
              if (flow.isActive)
                const AppPill.primary(label: 'Activo', dot: AppPillDot.active)
              else
                const AppPill.neutral(label: 'Pausado', dot: AppPillDot.paused),
            ],
          ),
          const SizedBox(height: AppTokens.sp6),
          Text(
            'Pasos',
            style: textTheme.titleMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp3),
          if (steps.isEmpty)
            Text(
              'Este flujo aún no tiene pasos.',
              key: const Key('flow_detail.steps.empty'),
              style: textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppTokens.text2,
              ),
            )
          else
            for (final s in steps) ...<Widget>[
              _StepCard(step: s),
              const SizedBox(height: AppTokens.sp3),
            ],
        ],
      ),
    );
  }
}

/// Card read-only por step. Muestra index (order+1), label humanizado del
/// type, contenido (`content` para TEXT, `mediaRef` para multimedia,
/// resumen de metadata para CONDITIONAL_TIME), y pills laterales (delay,
/// aiOnly si aplica).
class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final sdom.Step step;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      key: Key('flow_detail.step_card.${step.id}'),
      padding: AppTokens.sp4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '${step.order + 1}.',
                style: textTheme.titleMedium?.copyWith(color: AppTokens.text2),
              ),
              const SizedBox(width: AppTokens.sp2),
              Text(_humanLabelFor(step.type), style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppTokens.sp2),
          _StepBody(step: step, textTheme: textTheme),
          const SizedBox(height: AppTokens.sp3),
          Wrap(
            spacing: AppTokens.sp2,
            runSpacing: AppTokens.sp2,
            children: <Widget>[
              AppPill.neutral(label: _delayLabel(step)),
              if (step.aiOnly) const AppPill.primary(label: 'Solo IA'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cuerpo del step según tipo. TEXT muestra content; multimedia muestra
/// mediaRef truncado; CONDITIONAL_TIME muestra placeholder ya que F2 no
/// interpreta metadata (F7 lo hará).
class _StepBody extends StatelessWidget {
  const _StepBody({required this.step, required this.textTheme});

  final sdom.Step step;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final t = step.type;
    if (t == sdom.StepType.text) {
      final content = step.content.isEmpty ? '—' : step.content;
      return Text(
        content,
        style: textTheme.bodyMedium?.copyWith(
          color: step.content.isEmpty ? AppTokens.text2 : null,
        ),
      );
    }
    if (t == sdom.StepType.conditionalTime) {
      return Text(
        'Condicional por horario (configurable en el editor).',
        style: textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      );
    }
    // Multimedia: IMAGE / VIDEO / DOCUMENT / AUDIO / PTT / STICKER.
    if (step.mediaRef.isEmpty) {
      return Text(
        'Sin media asignada',
        style: textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          step.mediaRef,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            color: AppTokens.text2,
          ),
        ),
        if (step.content.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppTokens.sp1),
          Text(step.content, style: textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final FlowsFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is FlowsNotFoundFailure;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: isNotFound
          ? const Key('flow_detail.error.not_found')
          : const Key('flow_detail.error.generic'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              isNotFound
                  ? 'Este flujo ya no existe en tu organización'
                  : 'No pudimos cargar el detalle del flujo',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            if (!isNotFound) ...<Widget>[
              const SizedBox(height: AppTokens.sp3),
              AppButton.tonal(
                label: 'Reintentar',
                onPressed: () => context.read<FlowDetailBloc>().add(
                  const FlowDetailLoadRequested(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _humanLabelFor(sdom.StepType t) => switch (t) {
  sdom.StepType.text => 'Texto',
  sdom.StepType.image => 'Imagen',
  sdom.StepType.video => 'Video',
  sdom.StepType.document => 'Documento',
  sdom.StepType.audio => 'Audio',
  sdom.StepType.ptt => 'Nota de voz',
  sdom.StepType.sticker => 'Sticker',
  sdom.StepType.conditionalTime => 'Condicional',
};

/// Etiqueta legible del delay. Convierte ms a segundos con un decimal y
/// agrega el jitter si > 0. Ejemplos: "0s" / "1.5s" / "2s ± 10%".
String _delayLabel(sdom.Step s) {
  final secs = s.delayMs / 1000;
  final base = secs == secs.truncate()
      ? '${secs.toInt()}s'
      : '${secs.toStringAsFixed(1)}s';
  if (s.jitterPct <= 0) return base;
  return '$base ± ${s.jitterPct}%';
}
