import 'package:pokem_app/model/purchase/purchase.dart';

class ReviewRecord {
  const ReviewRecord({
    required this.code,
    required this.purchaseCode,
    required this.productCode,
    required this.userId,
    required this.rating,
    required this.contents,
    required this.date,
  });
  final String code, purchaseCode, productCode, userId, contents, date;
  final int rating;
  factory ReviewRecord.fromJson(Map<String, dynamic> json) => ReviewRecord(
    code: json['review_code'] as String,
    purchaseCode: json['purchase_item_purchase_item_code'] as String,
    productCode: json['sell_product_sell_product_code'] as String,
    userId: json['user_user_id'] as String,
    rating: json['review_rating'] as int,
    contents: json['review_contents'] as String,
    date: json['review_date'] as String,
  );
}

class ReviewSnapshot {
  const ReviewSnapshot(this.purchase, this.review);
  final Purchase purchase;
  final ReviewRecord? review;
  bool get canWrite => purchase.isConfirmed && review == null;
}

class ReviewException implements Exception {
  const ReviewException(this.message, {this.status, this.uncertain = false});
  final String message;
  final int? status;
  final bool uncertain;
  @override
  String toString() => message;
}

class SellerReviewSummary {
  const SellerReviewSummary(this.reviews);
  final List<ReviewRecord> reviews;
  int get count => reviews.length;
  double? get averageRating => reviews.isEmpty
      ? null
      : reviews.fold<int>(0, (total, row) => total + row.rating) /
            reviews.length;
}
