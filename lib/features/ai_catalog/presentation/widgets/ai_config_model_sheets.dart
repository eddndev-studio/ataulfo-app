import 'package:flutter/material.dart';

import '../../../../core/ai/ai_config.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_option_row.dart';
import '../../domain/entities/catalog.dart';

/// Picker de modelo agrupado por proveedor para el editor de [AIConfig].
/// Tap = elegir y cerrar; devuelve el par proveedor+modelo (elegir un modelo
/// de otro proveedor cambia también el proveedor). Las keys se derivan de
/// [keyPrefix] para que cada superficie consumidora conserve las suyas.
class AiConfigModelSheet extends StatelessWidget {
  const AiConfigModelSheet({
    super.key,
    required this.keyPrefix,
    required this.catalog,
    required this.current,
  });

  final String keyPrefix;
  final Catalog catalog;
  final String current;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        key: Key('$keyPrefix.sheet.model'),
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp6,
          AppTokens.sp6,
          AppTokens.sp6,
          AppTokens.sp6 + context.sheetBottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Modelo', style: textTheme.titleLarge),
            const SizedBox(height: AppTokens.sp4),
            for (final entry in catalog.providers)
              ..._providerSection(context, entry, textTheme),
          ],
        ),
      ),
    );
  }

  List<Widget> _providerSection(
    BuildContext context,
    ProviderEntry entry,
    TextTheme textTheme,
  ) {
    // Un proveedor que este release no reconoce se omite: no podemos
    // construir el AIProvider del PUT (el backend puede ir adelante).
    final AIProvider provider;
    try {
      provider = AIProvider.fromWire(entry.provider);
    } on ArgumentError {
      return const <Widget>[];
    }
    return <Widget>[
      _providerHeader(entry.provider, textTheme),
      for (final m in entry.models)
        AppOptionRow(
          key: Key('$keyPrefix.model.${m.id}'),
          title: m.id,
          // Badges de modalidad de ENTRADA: qué adjuntos del cliente
          // puede VER este modelo. Sin flags = solo texto, sin ruido.
          trailing: _modalityBadges(m),
          selected: m.id == current,
          onTap: () =>
              Navigator.of(context).pop((provider: provider, model: m.id)),
        ),
    ];
  }
}

/// Íconos de modalidad de entrada de un modelo (imagen / audio / documento).
List<Widget> _modalityBadges(AIModel m) => <Widget>[
  if (m.supportsImageInput)
    const Padding(
      padding: EdgeInsets.only(left: AppTokens.sp1),
      child: Icon(Icons.image_outlined, size: 16, color: AppTokens.text2),
    ),
  if (m.supportsAudioInput)
    const Padding(
      padding: EdgeInsets.only(left: AppTokens.sp1),
      child: Icon(Icons.mic_none, size: 16, color: AppTokens.text2),
    ),
  if (m.supportsDocumentInput)
    const Padding(
      padding: EdgeInsets.only(left: AppTokens.sp1),
      child: Icon(Icons.description_outlined, size: 16, color: AppTokens.text2),
    ),
];

/// Picker del modelo de subagentes, agrupado por proveedor como
/// [AiConfigModelSheet]. La primera opción es "Heredar (modelo principal)";
/// el resto son los modelos del catálogo vivo. Devuelve un record cuyo campo
/// `selection` es `null` para Heredar o un [SubagentModel] para un modelo
/// concreto (el record deja al llamador distinguir "elegir Heredar" de
/// "cerrar sin elegir"). Tap = elegir y cerrar.
class AiConfigSubagentSheet extends StatelessWidget {
  const AiConfigSubagentSheet({
    super.key,
    required this.keyPrefix,
    required this.catalog,
    required this.current,
  });

  final String keyPrefix;
  final Catalog catalog;
  final SubagentModel? current;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        key: Key('$keyPrefix.sheet.subagent'),
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp6,
          AppTokens.sp6,
          AppTokens.sp6,
          AppTokens.sp6 + context.sheetBottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Modelo de subagentes', style: textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              'El modelo con el que corren los subagentes que el bot delega. '
              'Heredar usa el mismo modelo principal de la plantilla.',
              style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
            AppOptionRow(
              key: Key('$keyPrefix.subagent.inherit'),
              title: 'Heredar (modelo principal)',
              selected: current == null,
              onTap: () => Navigator.of(context).pop((selection: null)),
            ),
            for (final entry in catalog.providers)
              ..._providerSection(context, entry, textTheme),
          ],
        ),
      ),
    );
  }

  List<Widget> _providerSection(
    BuildContext context,
    ProviderEntry entry,
    TextTheme textTheme,
  ) {
    // Un proveedor que este release no reconoce se omite: no podemos
    // construir el AIProvider del PUT (el backend puede ir adelante).
    final AIProvider provider;
    try {
      provider = AIProvider.fromWire(entry.provider);
    } on ArgumentError {
      return const <Widget>[];
    }
    return <Widget>[
      _providerHeader(entry.provider, textTheme),
      for (final m in entry.models)
        AppOptionRow(
          key: Key('$keyPrefix.subagent.model.${m.id}'),
          title: m.id,
          selected: current?.provider == provider && current?.model == m.id,
          onTap: () => Navigator.of(
            context,
          ).pop((selection: SubagentModel(provider: provider, model: m.id))),
        ),
    ];
  }
}

/// Rótulo de la sección de un proveedor dentro de los pickers agrupados.
Widget _providerHeader(String label, TextTheme textTheme) => Padding(
  padding: const EdgeInsets.only(top: AppTokens.sp3, bottom: AppTokens.sp1),
  child: Text(
    label,
    style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
  ),
);
