import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/public_catalog_settings.dart';
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
              child: CircularProgressIndicator(),
            ),
            PublicCatalogStatus.error => _ErrorView(
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
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
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Catálogo público'),
            subtitle: const Text(
              'Muestra tus productos activos en una página web que puedes '
              'compartir con tus clientes.',
            ),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _slug,
            decoration: const InputDecoration(
              labelText: 'Enlace (opcional)',
              helperText: 'Minúsculas, números y guiones. Ej.: tacos-dona-mary',
              border: OutlineInputBorder(),
            ),
            autocorrect: false,
            enableSuggestions: false,
          ),
          if (_enabled && url != null && url.isNotEmpty) ...[
            const SizedBox(height: 16),
            _UrlRow(url: url),
          ],
          const SizedBox(height: 24),
          BlocBuilder<PublicCatalogCubit, PublicCatalogState>(
            buildWhen: (a, b) => a.saving != b.saving,
            builder: (context, state) => FilledButton(
              onPressed: state.saving ? null : _save,
              child: state.saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}

/// La URL pública con un botón para copiarla al portapapeles.
class _UrlRow extends StatelessWidget {
  const _UrlRow({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SelectableText(url, style: const TextStyle(fontSize: 14)),
        ),
        IconButton(
          tooltip: 'Copiar enlace',
          icon: const Icon(Icons.copy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Enlace copiado.')));
            }
          },
        ),
      ],
    );
  }
}
