import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/review/review_record.dart';

class ProductReviewsVm extends AsyncNotifier<List<ReviewRecord>> {
  ProductReviewsVm(this.code);
  final String code;
  @override
  Future<List<ReviewRecord>> build() =>
      ref.watch(reviewRepositoryProvider).list(code);
  void refresh() => ref.invalidateSelf();
}

final productReviewsVmProvider = AsyncNotifierProvider.autoDispose
    .family<ProductReviewsVm, List<ReviewRecord>, String>(
      ProductReviewsVm.new,
      retry: (_, _) => null,
    );
