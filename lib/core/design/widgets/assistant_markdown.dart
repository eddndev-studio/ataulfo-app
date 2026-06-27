import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../tokens.dart';

/// Render Markdown del texto del rol assistant (negrita, cursiva, código,
/// listas, encabezados, citas). Reemplazo drop-in del `Text(content)` donde
/// un agente conversacional emite CommonMark, para la sensación de un chat de
/// primer nivel. El `MarkdownStyleSheet` se mapea a [AppTokens] para que el
/// resultado combine con el design system, y los encabezados se acotan a la
/// tipografía de título: un `#` no puede reventar la burbuja de chat.
///
/// Vive en `core/design` porque lo comparten las superficies con rol assistant
/// (entrenador y asistente de plataforma). Las superficies que transcriben
/// WhatsApp verbatim NO lo usan: ahí el texto debe verse igual que lo recibió
/// el cliente, no reinterpretado como CommonMark.
class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown({required this.data, super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(data: data, styleSheet: _styleSheet(context));
  }

  MarkdownStyleSheet _styleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final body = (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
      color: AppTokens.text1,
    );
    TextStyle heading(double size, FontWeight weight) =>
        body.copyWith(fontSize: size, fontWeight: weight);

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: body,
      strong: body.copyWith(fontWeight: FontWeight.w700),
      em: body.copyWith(fontStyle: FontStyle.italic),
      a: body.copyWith(
        color: AppTokens.chatAccent,
        decoration: TextDecoration.underline,
      ),
      listBullet: body,
      code: body.copyWith(
        fontFamily: 'monospace',
        backgroundColor: AppTokens.surface3,
      ),
      codeblockPadding: const EdgeInsets.all(AppTokens.sp2),
      codeblockDecoration: BoxDecoration(
        color: AppTokens.surface3,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      blockquote: body.copyWith(color: AppTokens.text2),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppTokens.divider, width: 3)),
      ),
      h1: heading(AppTokens.titleLSize, FontWeight.w700),
      h2: heading(AppTokens.titleMSize, FontWeight.w600),
      h3: heading(AppTokens.bodyLSize, FontWeight.w600),
      h4: heading(AppTokens.bodyLSize, FontWeight.w600),
    );
  }
}
