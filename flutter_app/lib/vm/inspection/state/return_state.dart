import 'package:pokem_app/model/inspection/return_item.dart';

class ReturnState {
  const ReturnState({
    required this.items,
    required this.nextOffset,
    required this.hasMore,
    this.loadingMore = false,
    this.error,
  });
  final List<ReturnItem> items;
  final int nextOffset;
  final bool hasMore, loadingMore;
  final String? error;
}
