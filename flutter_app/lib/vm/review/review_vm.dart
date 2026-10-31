import 'package:pokem_app/vm/review/seller_reviews_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/model/review/review_record.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/review/product_reviews_vm.dart';
import 'package:pokem_app/vm/review/state/review_state.dart';

class ReviewVm extends Notifier<ReviewState> {
  ReviewVm(this.code);
  final String code;
  @override
  ReviewState build() {
    ref.watch(loginVmProvider.select((s) => s.session?.token));
    Future.microtask(() => load(initial: true));
    return const ReviewState();
  }

  bool _current(String token) =>
      ref.mounted && ref.read(authRepositoryProvider).session?.token == token;
  String? validateContents(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '후기를 입력해주세요.';
    if (text.length > 500) return '후기는 500자 이하여야 합니다.';
    return null;
  }

  void rate(int rating) {
    if (state.locked || rating < 1 || rating > 5) return;
    state = ReviewState(
      snapshot: state.snapshot,
      rating: rating,
      loading: false,
    );
  }

  Future<void> load({bool initial = false}) async {
    if (!ref.mounted || state.saving || (!initial && state.loading)) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    final previous = state;
    state = ReviewState(
      snapshot: previous.snapshot,
      rating: previous.rating,
      uncertain: previous.uncertain,
    );
    try {
      final snapshot = await ref
          .read(reviewRepositoryProvider)
          .snapshot(code, session.token);
      if (!_current(session.token)) return;
      final uncertain = previous.uncertain && snapshot.review == null;
      state = ReviewState(
        snapshot: snapshot,
        rating: snapshot.review?.rating ?? previous.rating,
        loading: false,
        uncertain: uncertain,
        error: uncertain ? '아직 후기가 확인되지 않았습니다. 잠시 후 다시 확인해주세요.' : null,
      );
    } catch (e) {
      if (!_current(session.token)) return;
      state = ReviewState(
        snapshot: previous.snapshot,
        rating: previous.rating,
        loading: false,
        uncertain: previous.uncertain,
        error: _message(e),
      );
      await _unauthorized(e);
    }
  }

  Future<void> save(String contents) async {
    if (state.locked || state.snapshot?.canWrite != true) return;
    final error = state.rating < 1 || state.rating > 5
        ? '별점을 선택해주세요.'
        : validateContents(contents);
    if (error != null) {
      state = ReviewState(
        snapshot: state.snapshot,
        rating: state.rating,
        loading: false,
        error: error,
      );
      return;
    }
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.isExpired) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    final snapshot = state.snapshot!;
    final rating = state.rating;
    state = ReviewState(
      snapshot: snapshot,
      rating: rating,
      loading: false,
      saving: true,
    );
    try {
      final result = await ref
          .read(reviewRepositoryProvider)
          .create(snapshot.purchase, rating, contents.trim(), session.token);
      if (!_current(session.token)) return;
      state = ReviewState(
        snapshot: ReviewSnapshot(snapshot.purchase, result),
        rating: result.rating,
        loading: false,
      );
      ref.invalidate(productReviewsVmProvider(result.productCode));
      ref.invalidate(sellerReviewsVmProvider);
    } catch (e) {
      if (!_current(session.token)) return;
      final uncertain = e is! ReviewException || e.uncertain;
      state = ReviewState(
        snapshot: snapshot,
        rating: rating,
        loading: false,
        uncertain: uncertain,
        error: uncertain ? '저장 결과를 확인하지 못했습니다. 작성한 후기를 확인해주세요.' : _message(e),
      );
      await _unauthorized(e);
    }
  }

  String _message(Object e) => e is ReviewException
      ? e.message
      : e is PurchaseException
      ? e.message
      : '후기 정보를 확인하지 못했습니다.';
  Future<void> _unauthorized(Object e) async {
    if ((e is ReviewException && e.status == 401) ||
        (e is PurchaseException && e.status == 401)) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }
}

final reviewVmProvider = NotifierProvider.family<ReviewVm, ReviewState, String>(
  ReviewVm.new,
);
