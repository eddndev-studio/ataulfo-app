import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/provider_badge.dart';
import '../../../templates/domain/entities/template.dart';
import '../../../templates/presentation/bloc/templates_bloc.dart';

/// Selector de plantilla para arrancar la creación de un bot desde la tab
/// Bots. Consume el `TemplatesBloc` del scope; el cableado del provider y
/// el dispatch del primer load lo hace el router en `/bots/new`. Es
/// content-only: el Scaffold y el AppBar los aporta la ruta.
///
/// Al elegir una plantilla la navegación es `pushReplacement` a
/// `/templates/:templateId/bots/new?name=...`. El picker es transitorio:
/// una vez seleccionada, no agrega valor regresar a él — el back físico
/// del form vuelve al shell, no a esta lista intermedia.
class BotTemplatePickerPage extends StatelessWidget {
  const BotTemplatePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TemplatesBloc, TemplatesState>(
      builder: (context, state) => switch (state) {
        TemplatesInitial() || TemplatesLoading() => const _LoadingView(),
        TemplatesLoaded(items: final items) => _LoadedView(items: items),
        TemplatesFailed() => const _FailedView(),
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
  const _LoadedView({required this.items});

  final List<Template> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyView();
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp4,
        vertical: AppTokens.sp4,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTokens.cardGap),
      itemBuilder: (_, i) => _TemplateTile(template: items[i]),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('bot_template_picker.empty'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No tienes plantillas todavía.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp2),
            Text(
              'Crea una desde la tab Plantillas para poder crear bots.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('bot_template_picker.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No pudimos cargar tus plantillas',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<TemplatesBloc>().add(
                const TemplatesLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      // `encodeQueryComponent` (no `encodeFull`): el nombre va dentro
      // de un par clave=valor, así que `&` y `=` también deben
      // escaparse — encodeFull los preservaría y rompería el query.
      onTap: () {
        final name = Uri.encodeQueryComponent(template.name);
        context.pushReplacement(
          '/templates/${template.id}/bots/new?name=$name',
        );
      },
      child: Row(
        children: <Widget>[
          AppAvatar(name: template.name),
          const SizedBox(width: AppTokens.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(template.name, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                ProviderBadge(provider: template.ai.provider),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
