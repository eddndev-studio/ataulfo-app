import 'package:flutter/material.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_option_row.dart';
import '../../../../core/design/widgets/app_section_header.dart';
import '../../../ai_catalog/domain/entities/catalog.dart';
import '../../../ai_catalog/presentation/widgets/ai_config_stat_tile.dart';
import '../../domain/entities/org_ai_config.dart';

/// Etiqueta legible de un host (el wire viaja en MAYÚSCULAS). Un host
/// desconocido se muestra tal cual (forward-compat).
String hostLabel(String host) => switch (host) {
  'GEMINI' => 'Gemini',
  'OPENAI' => 'OpenAI',
  'MINIMAX' => 'MiniMax',
  'DEEPSEEK' => 'DeepSeek',
  'FIREWORKS' => 'Fireworks',
  _ => host,
};

/// Selección de host POR MODELO, en el mismo idioma tile+hoja que la card de
/// defaults de al lado. Por cada modelo del catálogo con hosts:
///
///   - un solo host ⇒ tile de solo-lectura (valor = el host, nota "Único
///     proveedor disponible"): la org no elige.
///   - dos o más ⇒ tile vivo cuyo valor es el host fijado (o "Automático");
///     tocarlo abre una hoja de opciones — "Automático" quita el pin (vuelve
///     al default del backend).
///
/// Los modelos sin hosts en el catálogo (wire viejo) se omiten.
class HostSelectionSection extends StatelessWidget {
  const HostSelectionSection({
    super.key,
    required this.catalog,
    required this.config,
    required this.enabled,
    required this.onHostChanged,
  });

  final Catalog catalog;
  final OrgAiConfig config;

  /// false durante un guardado en vuelo: los tiles quedan inertes-atenuados.
  final bool enabled;

  /// host == null ⇒ quitar el pin (volver al default).
  final void Function(String model, String? host) onHostChanged;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    for (final p in catalog.providers) {
      for (final m in p.models) {
        if (m.hosts.isEmpty) continue;
        tiles.add(_tile(context, m));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AppSectionHeader(
          title: 'Proveedor por modelo',
          caption:
              'Elige en qué proveedor corre cada modelo. Los de un solo '
              'proveedor quedan fijos.',
        ),
        const SizedBox(height: AppTokens.sp4),
        for (var i = 0; i < tiles.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppTokens.cardGap),
          tiles[i],
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, AIModel model) {
    final selected = config.hostFor(model.id);
    if (model.hosts.length < 2) {
      // Un solo host: informativo, mismo idioma de solo-lectura que el resto
      // de tiles del editor.
      return AiConfigStatTile(
        tileKey: Key('org_ai.host.${model.id}'),
        label: model.id,
        value: hostLabel(model.hosts.first),
        note: 'Único proveedor disponible',
      );
    }
    return AiConfigStatTile(
      tileKey: Key('org_ai.host.${model.id}'),
      label: model.id,
      value: selected == null ? 'Automático' : hostLabel(selected),
      enabled: enabled,
      onTap: () => _pickHost(context, model, selected),
    );
  }

  Future<void> _pickHost(
    BuildContext context,
    AIModel model,
    String? current,
  ) async {
    // Record: distingue "cerrar sin elegir" (null) de "elegir Automático"
    // (host: null).
    final picked = await showAppBottomSheet<({String? host})>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppTokens.sp6,
            AppTokens.sp6,
            AppTokens.sp6,
            AppTokens.sp6 + sheetContext.sheetBottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                model.id,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: AppTokens.sp3),
              AppOptionRow(
                key: Key('org_ai.host.${model.id}.auto'),
                title: 'Automático',
                selected: current == null,
                onTap: () =>
                    Navigator.of(sheetContext).pop((host: null as String?)),
              ),
              for (final h in model.hosts)
                AppOptionRow(
                  key: Key('org_ai.host.${model.id}.$h'),
                  title: hostLabel(h),
                  selected: current == h,
                  onTap: () =>
                      Navigator.of(sheetContext).pop((host: h as String?)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    onHostChanged(model.id, picked.host);
  }
}
