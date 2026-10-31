import 'package:pokem_app/model/inspection/deposit_refund.dart';

class DepositRefundState {
  const DepositRefundState({
    required this.items,
    required this.nextOffset,
    required this.hasMore,
    this.loadingMore = false,
    this.error,
  });
  final List<DepositRefund> items;
  final int nextOffset;
  final bool hasMore, loadingMore;
  final String? error;
}
