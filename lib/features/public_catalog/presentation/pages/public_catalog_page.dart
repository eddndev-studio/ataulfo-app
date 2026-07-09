import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toggle_row.dart';
import '../../domain/entities/catalog_appearance.dart';
import '../../domain/entities/public_catalog_settings.dart';
import '../appearance/appearance_section.dart';
import '../bloc/public_catalog_cubit.dart';
import '../public_catalog_copy.dart';

/// Ajustes del catálogo público de la org: encender/apagar la vitrina, elegir
/// el enlace (slug) y copiar la URL para compartirla. ADMIN+ (el backend lo
/// hace cumplir; un no-admin verá el copy de 403 al guardar).
class PublicCatalogPage extends StatelessWidget {
  const PublicCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo público')),
      body: BlocBuilder<PublicCatalogCubit, PublicCatalogState>(
        builder: (context, state) {
          return switch (state.status) {
            PublicCatalogStatus.loading => const Center(
              child: AppLoadingIndicator(),
            ),
            PublicCatalogStatus.error => AppErrorState(
              message: publicCatalogFailureCopy(state.loadFailure),
              onRetry: () => context.read<PublicCatalogCubit>().load(),
            ),
            PublicCatalogStatus.loaded => _SettingsForm(
              settings: state.settings!,
            ),
          };
        },
      ),
    );
  }
}

/// Formulario del estado cargado: mantiene el toggle y el slug en edición
/// local, y refleja el estado del backend cuando un guardado exitoso trae el
/// slug/url definitivos.
class _SettingsForm extends StatefulWidget {
  const _SettingsForm({required this.settings});

  final PublicCatalogSettings settings;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  late bool _enabled = widget.settings.enabled;
  late CatalogDesign _design = widget.settings.design;
  late CatalogAccent _accent = widget.settings.accent;
  late final TextEditingController _slug = TextEditingController(
    text: widget.settings.slug ?? '',
  );

  @override
  void didUpdateWidget(_SettingsForm old) {
    super.didUpdateWidget(old);
    // Un guardado exitoso puede haber acuñado/normalizado el slug: refleja el
    // valor del backend sin pisar una edición en curso del mismo texto.
    final fresh = widget.settings.slug ?? '';
    if (old.settings.slug != widget.settings.slug && _slug.text != fresh) {
      _slug.text = fresh;
    }
    if (old.settings.enabled != widget.settings.enabled) {
      _enabled = widget.settings.enabled;
    }
    // La apariencia también se reconcilia con lo que devolvió el backend.
    if (old.settings.design != widget.settings.design) {
      _design = widget.settings.design;
    }
    if (old.settings.accent != widget.settings.accent) {
      _accent = widget.settings.accent;
    }
  }

  @override
  void dispose() {
    _slug.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    context.read<PublicCatalogCubit>().save(
      enabled: _enabled,
      slug: _slug.text.trim(),
      design: _design,
      accent: _accent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.settings.url;
    return BlocListener<PublicCatalogCubit, PublicCatalogState>(
      listenWhen: (a, b) => a.saving && !b.saving,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state.saveFailure != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(publicCatalogFailureCopy(state.saveFailure)),
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('Catálogo público actualizado.')),
          );
        }
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp5,
          AppTokens.sp5,
          AppTokens.sp5,
          AppTokens.sp5 + context.safeBottomInset,
        ),
        children: <Widget>[
          AppToggleRow(
            switchKey: const Key('public_catalog.enabled'),
            label: 'Catálogo público',
            caption:
                'Muestra tus productos activos en una página web que puedes '
                'compartir con tus clientes.',
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: AppTokens.sp5),
          AppTextField(
            key: const Key('public_catalog.slug'),
            label: 'Enlace (opcional)',
            hint: 'tacos-dona-mary',
            controller: _slug,
            helperText: 'Minúsculas, números y guiones.',
            autocorrect: false,
          ),
          if (_enabled && url != null && url.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppTokens.sp5),
            _UrlCard(url: url),
          ],
          const SizedBox(height: AppTokens.sp7),
          AppearanceSection(
            design: _design,
            accent: _accent,
            onDesignChanged: (d) => setState(() => _design = d),
            onAccentChanged: (a) => setState(() => _accent = a),
            showOffHint: !_enabled,
          ),
          const SizedBox(height: AppTokens.sp7),
          BlocBuilder<PublicCatalogCubit, PublicCatalogState>(
            buildWhen: (a, b) => a.saving != b.saving,
            builder: (context, state) => AppButton.filled(
              key: const Key('public_catalog.save'),
              label: 'Guardar',
              fullWidth: true,
              loading: state.saving,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}

/// La URL pública en una tarjeta, con un botón para copiarla al portapapeles.
class _UrlCard extends StatelessWidget {
  const _UrlCard({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: SelectableText(
              url,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTokens.text1),
            ),
          ),
          IconButton(
            tooltip: 'Copiar enlace',
            icon: const Icon(Icons.copy, color: AppTokens.text2),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enlace copiado.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
