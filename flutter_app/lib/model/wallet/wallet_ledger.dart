enum LedgerDirection { all, incoming, outgoing }

class WalletMovement {
  const WalletMovement({
    required this.id,
    required this.kind,
    required this.amount,
    required this.ownerId,
    required this.sourceCode,
    this.date,
    this.paymentCode,
    this.purchaseCode,
    this.productCode,
    this.productTitle,
  });
  final String id, kind, ownerId, sourceCode;
  final int amount;
  final String? date, paymentCode, purchaseCode, productCode, productTitle;
  String get label => switch (kind) {
    'recharge' => '충전',
    'exchange' => '환전',
    'payment' => '상품 결제',
    'refund' => '취소 환불',
    'sale_credit' => '판매대금 입금',
    _ => '이용내역',
  };
  factory WalletMovement.fromJson(Map<String, dynamic> j) => WalletMovement(
    id: j['event_id'] as String,
    kind: j['kind'] as String,
    amount: j['amount'] as int,
    ownerId: j['user_user_id'] as String,
    sourceCode: j['source_code'] as String,
    date: j['occurred_at'] as String?,
    paymentCode: j['payment_code'] as String?,
    purchaseCode: j['purchase_code'] as String?,
    productCode: j['product_code'] as String?,
    productTitle: j['product_title'] as String?,
  );
}

class LedgerPage {
  const LedgerPage({
    required this.items,
    required this.nextOffset,
    required this.hasMore,
    this.loadingMore = false,
    this.error,
  });
  final List<WalletMovement> items;
  final int nextOffset;
  final bool hasMore, loadingMore;
  final String? error;
}

class LedgerException implements Exception {
  const LedgerException(this.message, {this.status});
  final String message;
  final int? status;
}
