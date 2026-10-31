import 'package:flutter/material.dart';
import 'package:pokem_app/core/formatters/purchase_time.dart';
import 'package:pokem_app/model/review/review_record.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});
  final ReviewRecord review;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 6),
              Text('${review.rating} / 5'),
            ],
          ),
          const SizedBox(height: 12),
          Text(review.contents),
          const SizedBox(height: 16),
          Text(
            '작성자 ${review.userId}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            formatPurchaseTime(review.date),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
