import 'package:flutter/material.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/view/products/widgets/product_image.dart';
import 'package:pokem_app/view/wishlist/widgets/wishlist_button.dart';

class ProductListingCard extends StatelessWidget {
  const ProductListingCard({
    super.key,
    required this.product,
    required this.actionKey,
    required this.onTap,
  });
  final Product product;
  final Key actionKey;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: actionKey,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: theme.colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ProductImage(
                        url: product.image,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: theme.colorScheme.surface.withValues(alpha: 0.95),
                      shape: const CircleBorder(),
                      child: WishlistButton(product: product),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    formatWon(product.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.status,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: product.isForSale
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
