import 'package:pokem_app/model/review/review_record.dart';

class ReviewState {
  const ReviewState({
    this.snapshot,
    this.rating = 0,
    this.loading = true,
    this.saving = false,
    this.uncertain = false,
    this.error,
  });
  final ReviewSnapshot? snapshot;
  final int rating;
  final bool loading, saving, uncertain;
  final String? error;
  bool get locked => loading || saving || uncertain || snapshot?.review != null;
}
