import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/vm/wishlist/wishlist_vm.dart';

class WishlistButton extends ConsumerWidget {
  const WishlistButton({super.key, required this.product});
  final Product product;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (wished, enabled) = ref.watch(
      wishlistVmProvider.select(
        (state) => (state.isWished(product.code), state.canToggle(product)),
      ),
    );
    return IconButton(
      key: ValueKey('wishlist-${product.code}'),
      tooltip: wished ? '관심 해제' : '관심 등록',
      onPressed: enabled
          ? () => ref.read(wishlistVmProvider.notifier).toggle(product)
          : null,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        child: Icon(
          wished ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(wished),
          color: wished ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
    );
  }
}
