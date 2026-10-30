import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class PurchaseCancelPage extends StatefulWidget {
  const PurchaseCancelPage({
    super.key,
    required this.token,
    required this.userId,
  });

  final String token;
  final String userId;

  @override
  State<PurchaseCancelPage> createState() => _PurchaseCancelPageState();
}

class _PurchaseCancelPageState extends State<PurchaseCancelPage> {
  late Future<_CancelData> _data;
  final Set<String> _busyCodes = <String>{};

  Map<String, String> get _headers =>
      {'Authorization': 'Bearer ${widget.token}'};

  @override
  void initState() {
    super.initState();
    _data = _fetchData();
  }

  Future<_CancelData> _fetchData() async {
    final responses = await Future.wait([
      http.get(Uri.parse('$apiBaseUrl/purchase_item'), headers: _headers),
      http.get(Uri.parse('$apiBaseUrl/purchase_cancel'), headers: _headers),
    ]).timeout(const Duration(seconds: 15));
    for (final response in responses) {
      if (response.statusCode != 200) throw Exception(_error(response));
    }
    final purchasesJson = jsonDecode(utf8.decode(responses[0].bodyBytes));
    final cancellationsJson = jsonDecode(utf8.decode(responses[1].bodyBytes));
    if (purchasesJson is! List || cancellationsJson is! List) {
      throw const FormatException('취소 내역 응답 형식이 올바르지 않습니다.');
    }
    return _CancelData(
      purchases: purchasesJson
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      cancellations: cancellationsJson
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
    );
  }

  Future<void> _refresh() async {
    final next = _fetchData();
    setState(() => _data = next);
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _requestCancel(Map<String, dynamic> purchase) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('결제 취소 요청'),
        content: TextField(
          controller: reasonController,
          maxLength: 255,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '취소 사유',
            hintText: '취소 사유를 입력해 주세요.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('취소 사유를 입력해 주세요.')),
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('요청하기'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;
    final purchaseCode =
        purchase['purchase_item_code']?.toString() ?? '';
    await _perform(
      key: purchaseCode,
      method: 'POST',
      uri: Uri.parse('$apiBaseUrl/purchase_cancel'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'purchase_item_purchase_item_code': purchaseCode,
        'purchase_cancel_reason': reason,
      }),
      successMessage: '취소 요청을 접수했습니다.',
    );
  }

  Future<void> _processCancel(
    Map<String, dynamic> cancellation,
    String action,
  ) async {
    final code = cancellation['purchase_cancel_code']?.toString() ?? '';
    final confirmText = switch (action) {
      'approve' => '승인하면 구매 사이버머니가 환급되고 거래가 취소됩니다. 승인할까요?',
      'reject' => '취소 요청을 거절할까요?',
      _ => '취소 요청을 철회할까요?',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('취소 요청 처리'),
        content: Text(confirmText),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('돌아가기')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('계속')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final uri = Uri.parse('$apiBaseUrl/purchase_cancel/'
        '${Uri.encodeComponent(code)}/$action');
    await _perform(
      key: code,
      method: 'POST',
      uri: uri,
      headers: _headers,
      successMessage: switch (action) {
        'approve' => '취소를 승인했습니다. 서버에서 사이버머니 환급을 처리했습니다.',
        'reject' => '취소 요청을 거절했습니다.',
        _ => '취소 요청을 철회했습니다.',
      },
    );
  }

  Future<void> _perform({
    required String key,
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
    required String successMessage,
  }) async {
    if (_busyCodes.contains(key)) return;
    setState(() => _busyCodes.add(key));
    try {
      final response = method == 'POST'
          ? await http.post(uri, headers: headers, body: body)
          : await http.get(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_error(response));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
      await _refresh();
    } catch (error) {
      if (mounted) _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busyCodes.remove(key));
    }
  }

  void _showMessage(String text) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('구매 취소 및 환불')),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<_CancelData>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _CancelMessage(
                  message: snapshot.error
                      .toString()
                      .replaceFirst('Exception: ', ''),
                  action: TextButton(
                      onPressed: _refresh,
                      child: const Text('다시 불러오기')),
                );
              }
              final data = snapshot.data!;
              final requestsByPurchase = <String, Map<String, dynamic>>{
                for (final request in data.cancellations)
                  request['purchase_item_purchase_item_code'].toString():
                      request,
              };
              final eligible = data.purchases.where((purchase) {
                final code = purchase['purchase_item_code']?.toString() ?? '';
                return _isInProgress(purchase['purchase_item_status']?.toString()) &&
                    !requestsByPurchase.containsKey(code);
              }).toList();
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const _CancelInfoBanner(),
                  const SizedBox(height: 20),
                  const Text('취소 가능 상품',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 9),
                  if (eligible.isEmpty)
                    const _CancelMessage(
                        message: '거래 중이고 기존 취소 요청이 없는 상품만 여기에 표시됩니다.'),
                  ...eligible.map((purchase) => _EligiblePurchaseCard(
                        purchase: purchase,
                        busy: _busyCodes.contains(
                            purchase['purchase_item_code']?.toString()),
                        onCancel: () => _requestCancel(purchase),
                      )),
                  const SizedBox(height: 18),
                  const Text('취소 요청 내역',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 9),
                  if (data.cancellations.isEmpty)
                    const _CancelMessage(message: '취소 요청 내역이 없습니다.'),
                  ...data.cancellations.map((request) => _CancellationCard(
                        cancellation: request,
                        currentUserId: widget.userId,
                        busy: _busyCodes.contains(
                            request['purchase_cancel_code']?.toString()),
                        onAction: (action) => _processCancel(request, action),
                      )),
                ],
              );
            },
          ),
        ),
      );
}

class _CancelData {
  const _CancelData({required this.purchases, required this.cancellations});
  final List<Map<String, dynamic>> purchases;
  final List<Map<String, dynamic>> cancellations;
}

class _EligiblePurchaseCard extends StatelessWidget {
  const _EligiblePurchaseCard({
    required this.purchase,
    required this.busy,
    required this.onCancel,
  });
  final Map<String, dynamic> purchase;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFEAECF2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('상품 코드  ${purchase['sell_product_sell_product_code'] ?? ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            SelectableText('구매 코드  ${purchase['purchase_item_code'] ?? ''}',
                maxLines: 2),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: busy ? null : onCancel,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('취소 요청'),
              ),
            ),
          ]),
        ),
      );
}

class _CancellationCard extends StatelessWidget {
  const _CancellationCard({
    required this.cancellation,
    required this.currentUserId,
    required this.busy,
    required this.onAction,
  });
  final Map<String, dynamic> cancellation;
  final String currentUserId;
  final bool busy;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final status = cancellation['purchase_cancel_status']?.toString() ?? '';
    final buyerId = cancellation['user_user_id']?.toString() ?? '';
    final sellerId = cancellation['seller_user_id']?.toString() ?? '';
    final pending = status == '요청중';
    final isBuyer = buyerId == currentUserId;
    final isSeller = sellerId == currentUserId;
    final showBuyerWithdraw = pending && isBuyer;
    final showSellerDecision = pending && isSeller && !isBuyer;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFEAECF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('취소 상태  $status',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            if (isBuyer) const Text('구매자', style: TextStyle(color: Color(0xFF858B9A))),
            if (isSeller) const Text('판매자', style: TextStyle(color: Color(0xFF6658E8))),
          ]),
          const SizedBox(height: 5),
          SelectableText(
              '취소 요청 코드  ${cancellation['purchase_cancel_code'] ?? ''}',
              maxLines: 2),
          Text('구매 코드  ${cancellation['purchase_item_purchase_item_code'] ?? ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('사유  ${cancellation['purchase_cancel_reason'] ?? ''}'),
          if (cancellation['response_reason'] != null) ...[
            const SizedBox(height: 3),
            Text('응답  ${cancellation['response_reason']}'),
          ],
          if (showBuyerWithdraw || showSellerDecision) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                if (showBuyerWithdraw)
                  OutlinedButton(
                    onPressed: busy ? null : () => onAction('withdraw'),
                    child: const Text('요청 철회'),
                  ),
                if (showSellerDecision) ...[
                  OutlinedButton(
                    onPressed: busy ? null : () => onAction('reject'),
                    child: const Text('거절'),
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => onAction('approve'),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('승인 및 환급'),
                  ),
                ],
              ],
            ),
          ],
        ]),
      ),
    );
  }
}

class _CancelInfoBanner extends StatelessWidget {
  const _CancelInfoBanner();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '취소 가능 상품에는 거래 중이고 기존 취소 요청이 없는 구매만 표시됩니다. 판매자가 취소를 승인하면 서버가 사이버머니를 환급합니다. 구매 취소 요청 코드는 구매코드_취소요청일시, 환급 코드 cybermoney_pay_cancel_code는 사이버머니결제코드_결제취소일시 형식으로 서버가 생성합니다.',
          style: TextStyle(color: Color(0xFF747887), fontSize: 12),
        ),
      );
}

class _CancelMessage extends StatelessWidget {
  const _CancelMessage({required this.message, this.action});
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEAECF2)),
        ),
        child: Column(children: [
          Text(message, textAlign: TextAlign.center),
          if (action != null) action!,
        ]),
      );
}

Map<String, dynamic> _decode(http.Response response) {
  try {
    final value = jsonDecode(utf8.decode(response.bodyBytes));
    if (value is Map<String, dynamic>) return value;
  } catch (_) {}
  return <String, dynamic>{};
}

String _error(http.Response response) {
  final data = _decode(response);
  return data['detail']?.toString() ??
      '취소 요청에 실패했습니다. (${response.statusCode})';
}

bool _isInProgress(String? status) =>
    status?.trim() == '거래중' || status?.trim() == '거래 중';
