import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'cybermoney_give.dart';
import 'market_product.dart';

class PurchaseItemPage extends StatefulWidget {
  const PurchaseItemPage(
      {super.key, required this.token, required this.product});

  final String token;
  final MarketProduct product;

  @override
  State<PurchaseItemPage> createState() => _PurchaseItemPageState();
}

class _PurchaseItemPageState extends State<PurchaseItemPage> {
  bool _loading = false;
  String? _purchaseCode;
  bool _purchaseConfirmed = false;
  CybermoneyGiveReceipt? _giveReceipt;

  Future<void> _confirmPurchase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('구매 신청'),
        content: Text(
            '${formatMarketPrice(widget.product.price)}원이 보유 머니에서 차감됩니다. 구매하시겠어요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('구매하기')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/purchase_item'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.token}'
            },
            body: jsonEncode(
                {'sell_product_sell_product_code': widget.product.code}),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data is Map<String, dynamic>) {
        setState(
            () => _purchaseCode = data['purchase_item_code']?.toString() ?? '');
      } else {
        final message =
            data is Map<String, dynamic> ? data['detail']?.toString() : null;
        _showMessage(message ?? '구매 요청을 처리하지 못했습니다.');
      }
    } catch (_) {
      _showMessage('서버에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _finalizePurchase() async {
    final code = _purchaseCode;
    if (code == null || code.isEmpty) return;
    setState(() => _loading = true);
    try {
      final response = await http.post(
        Uri.parse(
            '$apiBaseUrl/purchase_item/${Uri.encodeComponent(code)}/confirm'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        setState(() {
          _purchaseConfirmed = true;
          _giveReceipt = CybermoneyGiveReceipt.fromConfirmResponse(data);
        });
      } else {
        final message =
            data is Map<String, dynamic> ? data['detail']?.toString() : null;
        _showMessage(message ?? '구매 확정을 처리하지 못했습니다.');
      }
    } catch (_) {
      _showMessage('서버에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('구매하기')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                    aspectRatio: 1.2,
                    child: ProductImageView(source: widget.product.image))),
            const SizedBox(height: 18),
            Text(widget.product.title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('${formatMarketPrice(widget.product.price)}원',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5144C8))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('상품 코드',
                      style: TextStyle(color: Color(0xFF747887), fontSize: 12)),
                  const SizedBox(height: 4),
                  SelectableText(widget.product.code,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  const Text('구매 코드는 이 상품 코드를 기준으로 API가 생성합니다.',
                      style: TextStyle(color: Color(0xFF747887), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_purchaseCode != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFFE5F5EC),
                    borderRadius: BorderRadius.circular(16)),
                child: Text(
                    _purchaseConfirmed
                        ? '구매 확정이 완료됐습니다.\n주문 번호: $_purchaseCode'
                        : '결제가 완료됐습니다. 상품을 확인한 뒤 구매를 확정해 주세요.\n주문 번호: $_purchaseCode',
                    style: const TextStyle(
                        color: Color(0xFF256B45),
                        height: 1.5,
                        fontWeight: FontWeight.w600)),
              ),
            if (_giveReceipt != null) ...[
              const SizedBox(height: 14),
              CybermoneyGiveReceiptCard(receipt: _giveReceipt!),
            ],
            if (_purchaseCode != null && !_purchaseConfirmed) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _finalizePurchase,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('구매 확정하기'),
                ),
              ),
            ] else if (_purchaseCode == null) ...[
              const Text('구매를 진행하면 보유 머니에서 상품 금액이 차감됩니다.',
                  style: TextStyle(color: Color(0xFF737A8A))),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _confirmPurchase,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6658E8)),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('구매 요청하기'),
                ),
              ),
            ],
          ],
        ),
      );
}
