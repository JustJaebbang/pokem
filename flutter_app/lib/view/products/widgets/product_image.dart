import 'package:flutter/material.dart';

import 'package:pokem_app/core/media/product_image_url.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.url, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final resolved = resolveProductImage(url);
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Center(
        child: Icon(
          Icons.style_outlined,
          size: 36,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
    );
    if (resolved == null) return placeholder;
    return Image.network(
      resolved,
      fit: fit,
      width: double.infinity,
      errorBuilder: (_, error, stackTrace) => placeholder,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}
