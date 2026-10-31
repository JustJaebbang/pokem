import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/review/review_record.dart';

class SellerReviewsVm extends AsyncNotifier<SellerReviewSummary> {
  SellerReviewsVm(this.sellerId);
  final String sellerId;
  @override
  Future<SellerReviewSummary> build() async => SellerReviewSummary(
    await ref.watch(reviewRepositoryProvider).listForSeller(sellerId),
  );
  void refresh() => ref.invalidateSelf();
}

final sellerReviewsVmProvider = AsyncNotifierProvider.autoDispose
    .family<SellerReviewsVm, SellerReviewSummary, String>(
      SellerReviewsVm.new,
      retry: (_, _) => null,
    );
