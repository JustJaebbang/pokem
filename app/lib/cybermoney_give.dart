import 'package:flutter/material.dart';

import 'market_product.dart';

class CybermoneyGiveReceipt {
  const CybermoneyGiveReceipt({
    required this.code,
    required this.paymentCode,
    required this.sellerId,
    required this.productCode,
    required this.price,
    required this.confirmedAt,
    required this.message,
  });

  final String code;
  final String paymentCode;
  final String sellerId;
  final String productCode;
  final int price;
  final String confirmedAt;
  final String message;

  factory CybermoneyGiveReceipt.fromConfirmResponse(
          Map<String, dynamic> json) =>
      CybermoneyGiveReceipt(
        code: (json['cybermoney_give_code'] ?? '').toString(),
        paymentCode: (json['cybermoney_pay_code'] ?? '').toString(),
        sellerId: (json['seller_user_id'] ?? '').toString(),
        productCode: (json['sell_product_code'] ?? '').toString(),
        price: (json['cybermoney_give_price'] as num?)?.toInt() ??
            int.tryParse('${json['cybermoney_give_price']}') ??
            0,
        confirmedAt: (json['post_item_complete_date'] ?? '').toString(),
        message: (json['message'] ?? '').toString(),
      );

  String get formattedCode {
    final prefix = '${paymentCode}_';
    if (!code.startsWith(prefix)) return code;
    final paidAt = code.substring(prefix.length);
    return RegExp(r'^\d{20}$').hasMatch(paidAt)
        ? '${paymentCode}_$paidAt'
        : code;
  }
}

class CybermoneyGiveReceiptCard extends StatelessWidget {
  const CybermoneyGiveReceiptCard({super.key, required this.receipt});

  final CybermoneyGiveReceipt receipt;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFE5F5EC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFC8E9D5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    color: Color(0xFF287D62)),
                SizedBox(width: 9),
                Expanded(
                  child: Text('판매자 지급 완료',
                      style: TextStyle(
                          color: Color(0xFF256B45),
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ReceiptRow(
              label: '지급 금액',
              value: '${formatMarketPrice(receipt.price)}원',
            ),
            _ReceiptRow(label: '판매자 ID', value: receipt.sellerId),
            _ReceiptRow(label: '상품 코드', value: receipt.productCode),
            _ReceiptRow(label: '사이버머니 결제 코드', value: receipt.paymentCode),
            const SizedBox(height: 10),
            const Text(
              '지급 코드 · 사이버머니결제코드_지급일시',
              style: TextStyle(
                  color: Color(0xFF47715A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            SelectableText(
              receipt.formattedCode,
              style: const TextStyle(
                  color: Color(0xFF256B45),
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
            if (receipt.confirmedAt.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '지급 일시 · ${receipt.confirmedAt.replaceFirst('T', ' ')}',
                style: const TextStyle(color: Color(0xFF47715A), fontSize: 12),
              ),
            ],
          ],
        ),
      );
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 124,
              child: Text(label,
                  style:
                      const TextStyle(color: Color(0xFF47715A), fontSize: 12)),
            ),
            Expanded(
              child: SelectableText(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Color(0xFF256B45),
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
            ),
          ],
        ),
      );
}
