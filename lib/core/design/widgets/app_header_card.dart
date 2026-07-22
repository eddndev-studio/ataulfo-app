import 'package:flutter/material.dart';

import '../tokens.dart';

/// Header rico para secciones que sí merecen tratamiento hero (Canales y
/// Etiquetas): una tarjeta full-bleed con fondo PRIMARIO que reemplaza al
/// AppBar. Las pantallas operativas frecuentes usan `AppPageHeader` para no
/// competir visualmente con el contenido ni con el contexto de organización.
///
/// Va pegada al borde superior —solo las esquinas inferiores son redondeadas—
/// y muestra el título; opcionalmente el saludo, el acceso al perfil, la marca
/// de agua y un [content] propio bajo el título.
///
/// Deliberadamente NO incluye acción de crear (la aporta el FAB del shell) ni
/// de buscar (el buscador vive siempre visible debajo del header): duplicarlas
/// aquí sería ruido.
///
/// Es full-bleed: el consumidor lo monta SIN el padding lateral del layout (el
/// padding interno lo pone la propia tarjeta). El padding superior reserva el
/// inset de status bar (`MediaQuery`) para que el contenido no quede bajo el
/// notch cuando va sin AppBar.
class AppHeaderCard extends StatelessWidget {
  const AppHeaderCard({
    super.key,
    required this.title,
    this.greeting,
    this.avatarInitial,
    this.onAvatarTap,
    this.watermark,
    this.content,
  }) : assert(
         (avatarInitial == null) == (onAvatarTap == null),
         'el avatar del header exige su acción (y viceversa)',
       );

  final String title;

  /// Saludo sobre el título. Sin él (y sin avatar) la fila superior no se
  /// pinta y el título abre la tarjeta.
  final String? greeting;

  /// Inicial del avatar de perfil; va en pareja con [onAvatarTap].
  final String? avatarInitial;
  final VoidCallback? onAvatarTap;

  /// Glifo grande de la sección, recortado y a baja opacidad, como marca de
  /// agua decorativa.
  final IconData? watermark;

  /// Contenido propio de la sección bajo el título (identidad, resumen…), del
  /// mismo lenguaje on-primary que el resto de la tarjeta.
  final Widget? content;

  /// Gradiente de marca VERTICAL (ámbar arriba → naranja abajo), específico de
  /// este header. No reutiliza `brandGradient` (diagonal) a propósito.
  static const LinearGradient _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[AppTokens.primary, AppTokens.accent],
  );

  TextStyle _t(double size, FontWeight w, {double alpha = 1.0}) => TextStyle(
    fontFamily: AppTokens.fontSans,
    fontSize: size,
    fontWeight: w,
    height: 1.15,
    color: AppTokens.onPrimary.withValues(alpha: alpha),
  );

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final hasTopRow = greeting != null || avatarInitial != null;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(AppTokens.radiusHeader),
        bottomRight: Radius.circular(AppTokens.radiusHeader),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: _gradient),
        child: Stack(
          children: <Widget>[
            // Marca de agua: glifo grande de la sección, recortado y a baja
            // opacidad. Decorativo ⇒ fuera del árbol semántico.
            if (watermark != null)
              Positioned(
                top: -10,
                bottom: -10,
                right: -30,
                child: ExcludeSemantics(
                  child: Icon(
                    watermark,
                    size: 200,
                    color: AppTokens.onPrimary.withValues(alpha: 0.10),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppTokens.sp5,
                topInset + AppTokens.sp5,
                AppTokens.sp5,
                AppTokens.sp6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (hasTopRow) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: greeting != null
                              ? Text(
                                  greeting!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _t(15, FontWeight.w600, alpha: 0.9),
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (avatarInitial != null) ...<Widget>[
                          const SizedBox(width: AppTokens.sp2),
                          _DarkCircle(
                            key: const Key('header.avatar'),
                            onTap: onAvatarTap!,
                            semanticLabel: 'Perfil',
                            child: Text(
                              avatarInitial!,
                              style: const TextStyle(
                                fontFamily: AppTokens.fontSans,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTokens.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppTokens.sp6),
                  ],
                  Text(
                    title,
                    style: AppTokens.heroTitle.copyWith(
                      color: AppTokens.onPrimary,
                    ),
                  ),
                  if (content != null) ...<Widget>[
                    const SizedBox(height: AppTokens.sp5),
                    content!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón circular oscuro con glifo ámbar, sobre el gradiente. Toca → onTap.
class _DarkCircle extends StatelessWidget {
  const _DarkCircle({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: AppTokens.onPrimary,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(child: ExcludeSemantics(child: child)),
          ),
        ),
      ),
    );
  }
}
