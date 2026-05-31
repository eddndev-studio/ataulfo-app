import 'package:flutter/material.dart';

import '../../domain/entities/media_asset.dart';

/// Miniatura de un asset en el grid de la galería. Skeleton — sin comportamiento
/// todavía; el render real (preview firmada o placeholder) llega en verde.
class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({super.key, required this.asset, this.onTap});

  final MediaAsset asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
