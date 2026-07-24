import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../safe_bottom.dart';
import '../tokens.dart';

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
