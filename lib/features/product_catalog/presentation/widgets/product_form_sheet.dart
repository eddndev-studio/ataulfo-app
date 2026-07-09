import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_switch.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../media/domain/entities/media_asset.dart';
import '../../domain/entities/product.dart';
import '../../domain/failures/product_catalog_failure.dart';
import '../peso_format.dart';
import '../product_thumb_resolver.dart';
import 'product_form_image_section.dart';

// Supera las 400 LOC a propósito: el wizard (los dos pasos + su navegación,
// validación y estado compartido) es una sola unidad cohesiva de UI. Partirlo
// dispersaría los controllers y callbacks que viven y se leen juntos.

/// Persiste el formulario y devuelve la falla o null (éxito). El precio ya
/// viaja en centavos; el mediaRef es el BARE de la galería ('' = sin imagen).
typedef ProductFormSubmit =
    Future<ProductCatalogFailure?> Function({
      required ProductKind kind,
      required String name,
      required String description,
      required String category,
      required int priceCents,
      required String mediaRef,
      required bool active,
    });

/// Cómo se elige la imagen de la galería. Default: la galería en modo picker
/// filtrada a imágenes (`/media/pick?type=image`); los tests inyectan fakes.
typedef ProductImagePicker = Future<MediaAsset?> Function(BuildContext context);

/// Cómo se resuelven los bytes de la miniatura (ref BARE + asset efímero del
/// picker si lo hay). Default: `ProductThumbResolver.session`.
typedef ProductThumbLoader =
    Future<Uint8List?> Function(String ref, {MediaAsset? asset});

/// Abre el flujo «Mejorar foto con IA» del producto y devuelve el ref BARE
/// del resultado ACEPTADO (la foto nueva del producto) o null si no se
/// aceptó nada. El wiring real vive en el router (repos de composición y
/// media); null aquí ⇒ la acción no se ofrece.
typedef ProductComposePhoto =
    Future<String?> Function(BuildContext context, Product product);

/// Formulario de crear/editar un producto del catálogo como hoja inferior, en
/// formato wizard de dos pasos dentro de una sola hoja: (1) lo básico —tipo,
/// nombre, precio, categoría— y (2) los detalles —descripción, imagen, mejora
/// con IA y, en edición, el toggle «Activo». En alta [initial] es null (nace
/// activo, sin toggle); en edición trae el producto. El precio se edita en
/// PESOS («1,250.00»; vacío = a consultar) y se envía en centavos. [onSubmit]
/// persiste y devuelve la falla o null.
class ProductFormSheet extends StatefulWidget {
  const ProductFormSheet({
    super.key,
    this.initial,
    this.categories = const <String>[],
    required this.onSubmit,
    this.pickImage,
    this.thumbLoader,
    this.composePhoto,
  });

  final Product? initial;

  /// Categorías existentes de la org: sugerencias tappables bajo el campo.
  final List<String> categories;
  final ProductFormSubmit onSubmit;
  final ProductImagePicker? pickImage;
  final ProductThumbLoader? thumbLoader;
  final ProductComposePhoto? composePhoto;

  static Future<void> open(
    BuildContext context, {
    Product? initial,
    List<String> categories = const <String>[],
    required ProductFormSubmit onSubmit,
    ProductImagePicker? pickImage,
    ProductThumbLoader? thumbLoader,
    ProductComposePhoto? composePhoto,
  }) => showAppBottomSheet<void>(
    context,
    backgroundColor: AppTokens.surface1,
    isScrollControlled: true,
    builder: (_) => ProductFormSheet(
      initial: initial,
      categories: categories,
      onSubmit: onSubmit,
      pickImage: pickImage,
      thumbLoader: thumbLoader,
      composePhoto: composePhoto,
    ),
  );

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _descCtrl;
  late ProductKind _kind;
  late bool _active;
  late String _mediaRef;

  /// Paso visible del wizard: 0 = básicos, 1 = detalles.
  int _step = 0;

  /// Asset efímero de la selección de ESTA sesión: habilita la descarga de
  /// la miniatura recién elegida. Solo describe a [_mediaRef]; jamás se
  /// persiste (lo que viaja es el ref BARE).
  MediaAsset? _pickedAsset;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final it = widget.initial;
    _nameCtrl = TextEditingController(text: it?.name ?? '');
    _priceCtrl = TextEditingController(
      text: formatCentsToPesos(it?.priceCents ?? 0),
    );
    _categoryCtrl = TextEditingController(text: it?.category ?? '');
    _descCtrl = TextEditingController(text: it?.description ?? '');
    _kind = it?.kind ?? ProductKind.product;
    _active = it?.active ?? true;
    _mediaRef = it?.mediaRef ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _categoryCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final pick = widget.pickImage;
    final asset = pick != null
        ? await pick(context)
        : await context.push<MediaAsset>('/media/pick?type=image');
    if (asset == null || !mounted) return;
    setState(() {
      _mediaRef = asset.ref;
      _pickedAsset = asset;
    });
  }

  /// La acción se ofrece solo editando un producto cuya foto YA vive en el
  /// servidor: la composición parte de esa imagen persistida, no de una
  /// selección local sin guardar.
  bool get _canComposePhoto =>
      widget.composePhoto != null && (widget.initial?.hasImage ?? false);

  Future<void> _composePhoto() async {
    final open = widget.composePhoto;
    final product = widget.initial;
    if (open == null || product == null || _busy) return;
    final ref = await open(context, product);
    if (ref == null || !mounted) return;
    // El backend ya cambió la foto del producto: el form la refleja (el
    // asset efímero del picker deja de describir al ref).
    setState(() {
      _mediaRef = ref;
      _pickedAsset = null;
    });
  }

  /// Valida los básicos (paso 1) y, si están bien, avanza a los detalles.
  /// Precio vacío = «a consultar» (válido); solo un texto no numérico rebota.
  void _next() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ponle un nombre al producto.');
      return;
    }
    if (parsePesosToCents(_priceCtrl.text) == null) {
      setState(
        () => _error =
            'Escribe un precio válido (p. ej. 1,250.00) o déjalo vacío.',
      );
      return;
    }
    setState(() {
      _error = null;
      _step = 1;
    });
  }

  void _back() => setState(() => _step = 0);

  Future<void> _save() async {
    if (_busy) return;
    final name = _nameCtrl.text.trim();
    // Los básicos se validan al avanzar; si algo se coló inválido, se regresa
    // al paso donde vive el campo para que el error sea accionable.
    if (name.isEmpty) {
      setState(() {
        _error = 'Ponle un nombre al producto.';
        _step = 0;
      });
      return;
    }
    final priceCents = parsePesosToCents(_priceCtrl.text);
    if (priceCents == null) {
      setState(() {
        _error = 'Escribe un precio válido (p. ej. 1,250.00) o déjalo vacío.';
        _step = 0;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await widget.onSubmit(
      kind: _kind,
      name: name,
      description: _descCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      priceCents: priceCents,
      mediaRef: _mediaRef,
      active: _active,
    );
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = _messageFor(failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp5,
          AppTokens.sp2,
          AppTokens.sp5,
          AppTokens.sp5 + context.sheetBottomInset,
        ),
        child: SingleChildScrollView(
          child: _step == 0 ? _basics(context) : _details(context),
        ),
      ),
    );
  }

  Widget _basics(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _WizardHeader(
          title: _isEdit ? 'Editar producto' : 'Nuevo producto',
          step: 0,
        ),
        const SizedBox(height: AppTokens.sp5),
        Wrap(
          spacing: AppTokens.sp2,
          children: <Widget>[
            AppChoiceChip(
              key: const Key('product_form.kind.product'),
              label: 'Producto',
              selected: _kind == ProductKind.product,
              onSelected: (_) => setState(() => _kind = ProductKind.product),
            ),
            AppChoiceChip(
              key: const Key('product_form.kind.service'),
              label: 'Servicio',
              selected: _kind == ProductKind.service,
              onSelected: (_) => setState(() => _kind = ProductKind.service),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.sp4),
        AppTextField(
          key: const Key('product_form.name'),
          label: 'Nombre',
          hint: 'Ej. Mango Ataulfo por caja',
          controller: _nameCtrl,
          autofocus: !_isEdit,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppTokens.sp4),
        AppTextField(
          key: const Key('product_form.price'),
          label: 'Precio (MXN)',
          hint: 'Ej. 1,250.00 — vacío = a consultar',
          controller: _priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppTokens.sp4),
        AppTextField(
          key: const Key('product_form.category'),
          label: 'Categoría (opcional)',
          hint: 'Ej. Fruta, Servicios…',
          controller: _categoryCtrl,
          textInputAction: TextInputAction.next,
        ),
        if (widget.categories.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppTokens.sp3),
          Wrap(
            spacing: AppTokens.sp2,
            runSpacing: AppTokens.sp2,
            children: <Widget>[
              for (final cat in widget.categories)
                AppChoiceChip(
                  key: Key('product_form.category_suggestion.$cat'),
                  label: cat,
                  selected: _categoryCtrl.text.trim() == cat,
                  onSelected: (_) => setState(() => _categoryCtrl.text = cat),
                ),
            ],
          ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppTokens.sp3),
          Text(
            _error!,
            key: const Key('product_form.error'),
            style: textTheme.bodySmall?.copyWith(color: AppTokens.danger),
          ),
        ],
        const SizedBox(height: AppTokens.sp5),
        AppButton.filled(
          key: const Key('product_form.next'),
          label: 'Siguiente',
          fullWidth: true,
          onPressed: _next,
        ),
      ],
    );
  }

  Widget _details(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _WizardHeader(
          title: 'Detalles del producto',
          step: 1,
          onBack: _busy ? null : _back,
        ),
        const SizedBox(height: AppTokens.sp5),
        AppTextField(
          key: const Key('product_form.description'),
          label: 'Descripción (opcional)',
          hint: 'Qué incluye, presentaciones, tiempos…',
          controller: _descCtrl,
          minLines: 3,
          maxLines: 6,
        ),
        const SizedBox(height: AppTokens.sp5),
        ProductFormImageSection(
          mediaRef: _mediaRef,
          pickedAsset: _pickedAsset,
          thumbLoader: widget.thumbLoader ?? ProductThumbResolver.session.load,
          enabled: !_busy,
          onPick: _pick,
          onRemove: () => setState(() {
            _mediaRef = '';
            _pickedAsset = null;
          }),
        ),
        if (_canComposePhoto) ...<Widget>[
          const SizedBox(height: AppTokens.sp3),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.tonal(
              key: const Key('product_form.compose_photo'),
              label: 'Mejorar foto con IA',
              icon: Icons.auto_awesome_outlined,
              onPressed: _busy ? null : _composePhoto,
            ),
          ),
        ],
        if (_isEdit) ...<Widget>[
          const SizedBox(height: AppTokens.sp5),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Activo', style: textTheme.bodyLarge),
                    Text(
                      'Los inactivos no se ofrecen ni se comparten.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTokens.text2,
                      ),
                    ),
                  ],
                ),
              ),
              AppSwitch(
                key: const Key('product_form.active'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppTokens.sp3),
          Text(
            _error!,
            key: const Key('product_form.error'),
            style: textTheme.bodySmall?.copyWith(color: AppTokens.danger),
          ),
        ],
        const SizedBox(height: AppTokens.sp5),
        AppButton.filled(
          key: const Key('product_form.save'),
          label: _isEdit ? 'Guardar cambios' : 'Crear producto',
          fullWidth: true,
          loading: _busy,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }

  String _messageFor(ProductCatalogFailure failure) => switch (failure) {
    ProductCatalogValidationFailure(:final message) =>
      message ?? 'Revisa los datos e inténtalo otra vez.',
    ProductCatalogForbiddenFailure() => 'No tienes permiso para esta acción.',
    ProductCatalogNetworkFailure() =>
      'Sin conexión. Revisa tu red e inténtalo otra vez.',
    ProductCatalogTimeoutFailure() =>
      'La operación tardó demasiado. Inténtalo otra vez.',
    _ => 'No se pudo guardar. Inténtalo otra vez.',
  };
}

/// Encabezado del paso: título, un botón «volver» opcional (paso 2) y el
/// indicador de progreso de dos puntos.
class _WizardHeader extends StatelessWidget {
  const _WizardHeader({required this.title, required this.step, this.onBack});

  final String title;

  /// Paso activo (0 o 1); ilumina el punto correspondiente.
  final int step;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        if (onBack != null) ...<Widget>[
          IconButton(
            key: const Key('product_form.back'),
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
          ),
          const SizedBox(width: AppTokens.sp1),
        ],
        Expanded(child: Text(title, style: textTheme.titleLarge)),
        _StepDots(active: step),
      ],
    );
  }
}

/// Dos puntos que marcan el paso vigente del wizard.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _dot(active == 0),
        const SizedBox(width: AppTokens.sp1),
        _dot(active == 1),
      ],
    );
  }

  Widget _dot(bool on) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: on ? AppTokens.primary : AppTokens.surface3,
    ),
  );
}
