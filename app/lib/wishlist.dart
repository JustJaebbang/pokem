import 'package:flutter/material.dart';

import 'market_product.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage(
      {super.key,
      required this.productsFuture,
      required this.savedCodes,
      required this.onToggleWishlist,
      required this.onOpenProduct,
      this.loadError,
      this.onRetry});

  final Future<List<MarketProduct>> productsFuture;
  final Set<String> savedCodes;
  final ValueChanged<MarketProduct> onToggleWishlist;
  final ValueChanged<MarketProduct> onOpenProduct;
  final String? loadError;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<MarketProduct>>(
        future: productsFuture,
        builder: (context, snapshot) {
          if (loadError != null) {
            return _WishlistEmpty(message: loadError!, onRetry: onRetry);
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const _WishlistEmpty(
                message: '상품을 불러오지 못했어요. 홈에서 새로고침해 주세요.');
          }
          final products = (snapshot.data ?? const <MarketProduct>[])
              .where((product) =>
                  savedCodes.contains(product.code) && product.status == '\ud310\ub9e4\uc911')
              .toList();
          if (products.isEmpty) {
            return const _WishlistEmpty(message: '관심상품이 비어 있어요.');
          }
          return GridView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.68),
            itemBuilder: (context, index) => ProductCard(
              product: products[index],
              isWishlisted: true,
              onFavorite: () => onToggleWishlist(products[index]),
              onTap: () => onOpenProduct(products[index]),
            ),
          );
        },
      );
}

class _WishlistEmpty extends StatelessWidget {
  const _WishlistEmpty({required this.message, this.onRetry});
  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.favorite_border_rounded,
              size: 44, color: Color(0xFF9AA0AD)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Color(0xFF737A8A))),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('다시 불러오기')),
        ]),
      );
}
