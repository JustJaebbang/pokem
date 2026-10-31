import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/review/review_record.dart';
import 'package:pokem_app/service/review/review_api_service.dart';
import 'package:pokem_app/view/review/seller_reviews_view.dart';

import 'auth_test.dart' as auth;
import 'review_test.dart' as reviews;

ReviewRecord record(int rating, String code) => ReviewRecord(
  code: code,
  purchaseCode: 'PI$code',
  productCode: 'P$code',
  userId: 'buyer',
  rating: rating,
  contents: '$code 후기',
  date: '2026-10-31T12:34:00+09:00',
);

class SellerReviewRepository extends reviews.FakeReviewRepository {
  SellerReviewRepository(this.rows);
  final List<ReviewRecord> rows;
  @override
  Future<List<ReviewRecord>> listForSeller(String sellerId) async => rows;
}

void main() {
  test(
    'seller API uses seller_user_id rather than reviewer id or product filter',
    () async {
      final api = ReviewApiService(
        MockClient((r) async {
          expect(r.url.path, '/review');
          expect(r.url.queryParameters, {'seller_user_id': 'seller01'});
          return auth.response([
            {
              'review_code': 'R1',
              'purchase_item_purchase_item_code': 'PI1',
              'sell_product_sell_product_code': 'P1',
              'user_user_id': 'buyer',
              'review_rating': 5,
              'review_contents': '좋은 거래',
              'review_date': '2026-10-31T12:00:00+09:00',
            },
          ]);
        }),
        baseUrl: 'http://test.local',
      );
      expect((await api.listForSeller('seller01')).single.userId, 'buyer');
    },
  );
  test(
    'average and count cover every returned review and empty has no rating',
    () {
      final summary = SellerReviewSummary([record(3, '1'), record(5, '2')]);
      expect(summary.count, 2);
      expect(summary.averageRating, 4.0);
      expect(const SellerReviewSummary([]).averageRating, isNull);
    },
  );
  testWidgets('seller page displays all-sale review summary on small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(
            SellerReviewRepository([record(3, '1'), record(5, '2')]),
          ),
        ],
        child: const MaterialApp(home: SellerReviewsView(sellerId: 'seller01')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('판매자 seller01'), findsOneWidget);
    expect(find.text('후기 2개'), findsOneWidget);
    expect(find.text('평균 별점 4.0 / 5'), findsOneWidget);
    expect(find.text('1 후기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('seller with no reviews does not display zero as an evaluation', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(
            SellerReviewRepository([]),
          ),
        ],
        child: const MaterialApp(home: SellerReviewsView(sellerId: 'seller01')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('후기 0개'), findsOneWidget);
    expect(find.text('아직 평가가 없습니다.'), findsOneWidget);
    expect(find.text('등록된 판매자 후기가 없습니다.'), findsOneWidget);
  });
}
