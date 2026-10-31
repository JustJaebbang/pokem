import 'package:pokem_app/view/review/seller_reviews_view.dart';
import 'package:pokem_app/view/review/product_reviews_view.dart';
import 'package:pokem_app/view/purchase/checkout_view.dart';
import 'package:pokem_app/vm/chat/chat_start_vm.dart';
import 'package:pokem_app/view/chat/chat_room_view.dart';
import 'package:pokem_app/view/wishlist/widgets/wishlist_button.dart';
import 'package:pokem_app/vm/wishlist/wishlist_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/vm/products/product_detail_vm.dart';
import 'package:pokem_app/view/products/widgets/product_image.dart';

class ProductDetailView extends ConsumerWidget {
  const ProductDetailView({super.key, required this.code});
  final String code;
  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    final room = await ref.read(chatStartVmProvider.notifier).open(code);
    if (!context.mounted || room == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChatRoomView(roomId: room.id)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(productDetailVmProvider(code));
    final chatStart = ref.watch(chatStartVmProvider);
    final wishlistError = ref.watch(
      wishlistVmProvider.select((state) => state.error),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('상품 상세'),
        actions: [
          if (result.asData != null)
            WishlistButton(product: result.asData!.value.product),
        ],
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error is ProductException ? error.message : '상품을 불러오지 못했습니다.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref
                      .read(productDetailVmProvider(code).notifier)
                      .refresh(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        data: (detail) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ProductImage(
                  url: detail.product.image,
                  fit: BoxFit.contain,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(label: Text(detail.product.status)),
                    if (chatStart.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          chatStart.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (wishlistError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wishlistError,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            TextButton(
                              onPressed: () => ref
                                  .read(wishlistVmProvider.notifier)
                                  .refresh(),
                              child: const Text('관심상품 다시 불러오기'),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      detail.product.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      formatWon(detail.product.price),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '등록 등급 · ${detail.product.grade == 'Unrank' ? '미지정' : detail.product.grade}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '상품번호 · ${detail.product.code}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProductReviewsView(productCode: code),
                        ),
                      ),
                      child: const Text('거래 후기 보기'),
                    ),
                    if (detail.product.sellerId?.isNotEmpty == true)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SellerReviewsView(
                              sellerId: detail.product.sellerId!,
                            ),
                          ),
                        ),
                        child: const Text('판매자 후기 보기'),
                      ),
                    const Divider(height: 40),
                    Text(
                      '상품 설명',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      detail.product.description.isEmpty
                          ? '등록된 설명이 없습니다.'
                          : detail.product.description,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          result.asData == null || result.asData!.value.isOwnProduct
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            result.asData!.value.canChat && !chatStart.opening
                            ? () => _openChat(context, ref)
                            : null,
                        child: Text(chatStart.opening ? '연결 중' : '채팅하기'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: result.asData!.value.canBuy
                            ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CheckoutView(code: code),
                                ),
                              )
                            : null,
                        child: const Text('구매하기'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
