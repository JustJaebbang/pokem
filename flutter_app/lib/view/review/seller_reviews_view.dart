import 'package:pokem_app/view/profile/widgets/public_profile_header.dart';
import 'package:pokem_app/vm/profile/public_profile_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/review/review_record.dart';
import 'package:pokem_app/view/review/review_card.dart';
import 'package:pokem_app/vm/review/seller_reviews_vm.dart';

class SellerReviewsView extends ConsumerWidget {
  const SellerReviewsView({super.key, required this.sellerId});
  final String sellerId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sellerReviewsVmProvider(sellerId);
    final result = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('판매자 후기'),
        actions: [
          IconButton(
            onPressed: result.isLoading
                ? null
                : () {
                    ref.read(provider.notifier).refresh();
                    ref.invalidate(publicProfileVmProvider(sellerId));
                  },
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e is ReviewException ? e.message : '판매자 후기를 불러오지 못했습니다.'),
                TextButton(
                  onPressed: () => ref.read(provider.notifier).refresh(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        data: (summary) => RefreshIndicator(
          onRefresh: () async {
            ref.read(provider.notifier).refresh();
            ref.invalidate(publicProfileVmProvider(sellerId));
            try {
              await ref.read(provider.future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              PublicProfileHeader(userId: sellerId),
              const SizedBox(height: 16),
              Text('후기 ${summary.count}개'),
              const SizedBox(height: 8),
              Text(
                summary.averageRating == null
                    ? '아직 평가가 없습니다.'
                    : '평균 별점 ${summary.averageRating!.toStringAsFixed(1)} / 5',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              if (summary.reviews.isEmpty) const Text('등록된 판매자 후기가 없습니다.'),
              for (final review in summary.reviews)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '상품번호 ${review.productCode}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    ReviewCard(review: review),
                    const SizedBox(height: 12),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
