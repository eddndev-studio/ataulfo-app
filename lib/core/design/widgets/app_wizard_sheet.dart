import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';
import '../safe_bottom.dart';
import '../tokens.dart';

/// Dirección espacial entre dos pasos consecutivos de un wizard.
enum AppWizardStepDirection { forward, backward }

/// Cambia el contenido de un paso con continuidad espacial, sin crossfade.
///
/// Cada [child] debe tener una key distinta. Al avanzar, la vista actual sale
/// por la izquierda y la siguiente entra por la derecha; al volver se invierte
/// el recorrido. [ClipRect] mantiene ambas páginas dentro del mismo viewport,
/// de modo que nunca parecen dos hojas superpuestas.
class AppWizardStepTransition extends StatelessWidget {
  const AppWizardStepTransition({
    super.key,
    required this.direction,
    required this.child,
  });

  final AppWizardStepDirection direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    assert(child.key != null, 'Cada paso del wizard necesita una key estable.');
    final incomingOffset = switch (direction) {
      AppWizardStepDirection.forward => const Offset(1, 0),
      AppWizardStepDirection.backward => const Offset(-1, 0),
    };
    final outgoingOffset = -incomingOffset;
    final currentKey = child.key;

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
          final isIncoming = transitionChild.key == currentKey;
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: AppTokens.ease,
            // La curva invertida conserva juntas ambas páginas durante la
            // salida: no se cruzan ni dejan ver un hueco entre ellas.
            reverseCurve: AppTokens.ease.flipped,
          );

          return SlideTransition(
            position: Tween<Offset>(
              begin: isIncoming ? incomingOffset : outgoingOffset,
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: transitionChild,
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
  const AppWizardSheet({super.key, required this.body, required this.footer});

  final Widget body;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return AnimatedPadding(
      duration: AppTokens.durationBase,
      curve: AppTokens.ease,
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

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Flexible(
                  child: SingleChildScrollView(
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.sp6,
                      AppTokens.sp2,
                      AppTokens.sp6,
                      AppTokens.sp5,
                    ),
                    child: body,
                  ),
                ),
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
  }) : assert(step > 0),
       assert(totalSteps > 0),
       assert(step <= totalSteps);

  final int step;
  final int totalSteps;
  final String title;
  final String description;

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
            Text('$step de $totalSteps · $title', style: textTheme.titleLarge),
            const SizedBox(height: AppTokens.sp2),
            Text(
              description,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
            Row(
              children: <Widget>[
                for (var index = 1; index <= totalSteps; index++) ...<Widget>[
                  if (index > 1) const SizedBox(width: AppTokens.sp2),
                  Expanded(
                    child: AnimatedContainer(
                      key: Key('app_wizard.progress.$index'),
                      duration: AppTokens.durationBase,
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
