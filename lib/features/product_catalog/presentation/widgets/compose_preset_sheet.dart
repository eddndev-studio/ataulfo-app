import 'package:flutter/material.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_switch.dart';
import '../../domain/failures/composition_failure.dart';
import '../compose_presets.dart';
import '../composition_copy.dart';

/// Encola la composición y devuelve la falla o null (éxito). [premium] pide
/// la calidad Pro/Business; false = la estándar del plan.
typedef ComposePresetSubmit =
    Future<CompositionFailure?> Function({
      required String preset,
      required bool premium,
    });

/// Selector de escena para «Mejorar foto con IA»: las 5 tarjetas de preset
/// (previews estáticos por degradado), el switch de calidad premium y
/// «Crear». En éxito se cierra (el estado del job lo muestra la hoja de
/// composiciones); un rechazo se explica inline y la hoja sigue abierta.
class ComposePresetSheet extends StatefulWidget {
  const ComposePresetSheet({super.key, required this.onCreate});

  final ComposePresetSubmit onCreate;

  static Future<void> open(
    BuildContext context, {
    required ComposePresetSubmit onCreate,
  }) => showAppBottomSheet<void>(
    context,
    backgroundColor: AppTokens.surface1,
    isScrollControlled: true,
    builder: (_) => ComposePresetSheet(onCreate: onCreate),
  );

  @override
  State<ComposePresetSheet> createState() => _ComposePresetSheetState();
}

class _ComposePresetSheetState extends State<ComposePresetSheet> {
  /// La primera escena arranca elegida: «Crear» siempre es un tap posible.
  String _preset = composePresets.first.id;
  bool _premium = false;
  bool _busy = false;
  String? _error;

  Future<void> _create() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await widget.onCreate(preset: _preset, premium: _premium);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = compositionErrorText(failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp5,
          AppTokens.sp2,
          AppTokens.sp5,
          AppTokens.sp5 + context.safeBottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Elige el fondo', style: textTheme.titleLarge),
              const SizedBox(height: AppTokens.sp2),
              Text(
                'La IA pondrá tu producto sobre la escena elegida. '
                'Tu foto original no se toca.',
                style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
              ),
              const SizedBox(height: AppTokens.sp5),
              Wrap(
                spacing: AppTokens.sp3,
                runSpacing: AppTokens.sp3,
                children: <Widget>[
                  for (final preset in composePresets)
                    _PresetCard(
                      key: Key('compose_preset.card.${preset.id}'),
                      preset: preset,
                      selected: _preset == preset.id,
                      onTap: _busy
                          ? null
                          : () => setState(() => _preset = preset.id),
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.sp5),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Calidad premium (Pro/Business)',
                      style: textTheme.bodyLarge,
                    ),
                  ),
                  AppSwitch(
                    key: const Key('compose_preset.premium'),
                    value: _premium,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _premium = v),
                  ),
                ],
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppTokens.sp3),
                Text(
                  _error!,
                  key: const Key('compose_preset.error'),
                  style: textTheme.bodySmall?.copyWith(color: AppTokens.danger),
                ),
              ],
              const SizedBox(height: AppTokens.sp5),
              AppButton.filled(
                key: const Key('compose_preset.create'),
                label: 'Crear',
                fullWidth: true,
                loading: _busy,
                onPressed: _busy ? null : _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de escena: el degradado evocador + el rótulo, con borde de
/// selección. Preview 100% estático — sin red ni assets.
class _PresetCard extends StatelessWidget {
  const _PresetCard({
    super.key,
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ComposePreset preset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: preset.colors,
              ),
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              border: Border.all(
                color: selected ? AppTokens.primary : AppTokens.divider,
                width: selected ? 2 : 1,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.sp2),
          SizedBox(
            width: 88,
            child: Text(
              preset.label,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: selected ? AppTokens.text1 : AppTokens.text2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
