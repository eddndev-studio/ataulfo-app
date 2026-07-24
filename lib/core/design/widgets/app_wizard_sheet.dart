import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';
import '../safe_bottom.dart';
import '../tokens.dart';

/// Dirección espacial entre dos pasos consecutivos de un wizard.
enum AppWizardStepDirection { forward, backward }

/// Releva contenido inline sin convertir cada paso en una hoja distinta.
///
/// Cada [child] debe tener una key distinta. El contenido saliente desaparece
/// primero y pierde interacción de inmediato; sólo después aparece el entrante
/// con un desplazamiento corto que conserva la dirección del recorrido.
class AppWizardInlineTransition extends StatelessWidget {
  const AppWizardInlineTransition({
    super.key,
    required this.direction,
    required this.child,
  });

  final AppWizardStepDirection direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    assert(child.key != null, 'Cada paso del wizard necesita una key estable.');
    final directionSign = switch (direction) {
      AppWizardStepDirection.forward => 1.0,
      AppWizardStepDirection.backward => -1.0,
    };

    return ClipRect(
      child: AnimatedSwitcher(
        duration: AppMotion.durationOf(context, AppTokens.durationBase),
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (transitionChild, animation) {
          return AnimatedBuilder(
            animation: animation,
            child: transitionChild,
            builder: (context, transitionChild) {
              final isOutgoing = animation.status == AnimationStatus.reverse;
              final elapsed = isOutgoing
                  ? 1 - animation.value
                  : animation.value;
              final phase = isOutgoing
                  ? (elapsed / 0.40).clamp(0.0, 1.0)
                  : ((elapsed - 0.45) / 0.55).clamp(0.0, 1.0);
              final curvedPhase = AppTokens.ease.transform(phase);
              final opacity = isOutgoing ? 1 - curvedPhase : curvedPhase;
              final translation = isOutgoing
                  ? -directionSign * 0.035 * curvedPhase
                  : directionSign * 0.035 * (1 - curvedPhase);
              final interactive =
                  !isOutgoing && animation.status == AnimationStatus.completed;

              return IgnorePointer(
                ignoring: !interactive,
                child: ExcludeSemantics(
                  excluding: !interactive,
                  child: Opacity(
                    opacity: opacity,
                    child: FractionalTranslation(
                      translation: Offset(translation, 0),
                      child: transitionChild,
                    ),
                  ),
                ),
              );
            },
          );
        },
        child: child,
      ),
    );
  }
}

/// Estructura canónica para formularios por pasos dentro de una hoja inferior.
///
/// El contenido puede crecer y desplazarse, mientras que [footer] permanece
/// visible. El inset del teclado/nav se aplica una sola vez a toda la
/// estructura para que las acciones nunca queden tapadas.
class AppWizardSheet extends StatelessWidget {
  const AppWizardSheet({
    super.key,
    required this.body,
    required this.footer,
    this.bodyViewportFraction,
  }) : assert(
         bodyViewportFraction == null ||
             (bodyViewportFraction > 0 && bodyViewportFraction <= 1),
       );

  final Widget body;
  final Widget footer;

  /// Fracción del alto máximo reservada al cuerpo desplazable.
  ///
  /// Úsala en wizards cuyos pasos tienen alturas muy distintas para conservar
  /// la geometría de la hoja; omítela en hojas compactas de un solo estado.
  final double? bodyViewportFraction;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.only(bottom: context.sheetBottomInset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : screenHeight;
          // Algunos hosts de prueba/embebidos sobreescriben MediaQuery sin
          // declarar `size`; las constraints siguen siendo la autoridad de
          // layout y evitan convertir el alto máximo en cero.
          final viewportHeight = screenHeight > 0
              ? screenHeight
              : availableHeight;
          final maxHeight = math.min(availableHeight, viewportHeight * 0.90);
          final scrollView = SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.fromLTRB(
              AppTokens.sp6,
              AppTokens.sp2,
              AppTokens.sp6,
              AppTokens.sp5,
            ),
            child: body,
          );
          final bodyViewport = bodyViewportFraction == null
              ? scrollView
              : SizedBox(
                  height: maxHeight * bodyViewportFraction!,
                  child: scrollView,
                );

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Flexible(child: bodyViewport),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppTokens.divider)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.sp6,
                      AppTokens.sp3,
                      AppTokens.sp6,
                      AppTokens.sp4,
                    ),
                    child: footer,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Encabezado de un paso: estado textual, explicación breve y progreso
/// segmentado. El texto sigue siendo la fuente de verdad accesible; la barra
/// sólo refuerza visualmente dónde está la persona.
class AppWizardStepHeader extends StatelessWidget {
  const AppWizardStepHeader({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.description,
    this.direction = AppWizardStepDirection.forward,
  }) : assert(step > 0),
       assert(totalSteps > 0),
       assert(step <= totalSteps);

  final int step;
  final int totalSteps;
  final String title;
  final String description;
  final AppWizardStepDirection direction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: 'Paso $step de $totalSteps: $title',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppWizardInlineTransition(
              direction: direction,
              child: Column(
                key: ValueKey<String>('$step:$title:$description'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$step de $totalSteps · $title',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppTokens.sp2),
                  Text(
                    description,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTokens.text2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.sp4),
            Row(
              children: <Widget>[
                for (var index = 1; index <= totalSteps; index++) ...<Widget>[
                  if (index > 1) const SizedBox(width: AppTokens.sp2),
                  Expanded(
                    child: AnimatedContainer(
                      key: Key('app_wizard.progress.$index'),
                      duration: AppMotion.durationOf(
                        context,
                        AppTokens.durationBase,
                      ),
                      curve: AppTokens.ease,
                      height: AppTokens.sp1,
                      decoration: BoxDecoration(
                        color: index <= step
                            ? AppTokens.primary
                            : AppTokens.divider,
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusPill,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
