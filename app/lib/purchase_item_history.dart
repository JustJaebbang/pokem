import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class PurchaseItemHistoryPage extends StatefulWidget {
  const PurchaseItemHistoryPage({super.key, required this.token});
  final String token;

  @override
  State<PurchaseItemHistoryPage> createState() => _PurchaseItemHistoryPageState();
}

class _PurchaseItemHistoryPageState extends State<PurchaseItemHistoryPage> {
  late Future<List<Map<String, dynamic>>> _purchases;
  final Set<String> _confirming = <String>{};

  @override
  void initState() {
    super.initState();
    _purchases = _fetchPurchases();
  }

  Future<List<Map<String, dynamic>>> _fetchPurchases() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/purchase_item'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception(_error(response));
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) throw const FormatException('구매 내역 응답 형식이 올바르지 않습니다.');
    return data.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> _refresh() async {
    final next = _fetchPurchases();
    setState(() => _purchases = next);
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _confirmPurchase(Map<String, dynamic> purchase) async {
    final code = purchase['purchase_item_code']?.toString() ?? '';
    if (code.isEmpty || _confirming.contains(code)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('구매 확정'),
        content: const Text('구매를 확정하면 판매자에게 사이버머니가 지급됩니다. 확정할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('확정')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _confirming.add(code));
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/purchase_item/${Uri.encodeComponent(code)}/confirm'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 15));
      final body = _decode(response);
      if (response.statusCode != 200) throw Exception(_error(response, body));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body['message']?.toString() ?? '구매가 확정되었습니다.')),
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming.remove(code));
    }
  }

  void _showDetails(Map<String, dynamic> purchase) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('구매 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _DetailLine(label: '구매 코드', value: purchase['purchase_item_code']?.toString() ?? ''),
              _DetailLine(label: '상품 코드', value: purchase['sell_product_sell_product_code']?.toString() ?? ''),
              _DetailLine(label: '구매 일시', value: _formatDate(purchase['purchase_item_date']?.toString() ?? '')),
              _DetailLine(label: '상태', value: _status(purchase['purchase_item_status']?.toString())),
              if (purchase['purchase_item_confirmed_at'] != null)
                _DetailLine(label: '확정 일시', value: _formatDate(purchase['purchase_item_confirmed_at'].toString())),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('구매 내역')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _purchases,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(snapshot.error.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
                    TextButton(onPressed: _refresh, child: const Text('다시 불러오기')),
                  ]),
                ),
              );
            }
            final purchases = snapshot.data ?? const <Map<String, dynamic>>[];
            if (purchases.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 160),
                    Icon(Icons.shopping_bag_outlined, size: 42, color: Color(0xFF9AA0AD)),
                    SizedBox(height: 12),
                    Center(child: Text('구매 내역이 없습니다.')),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: purchases.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final purchase = purchases[index];
                  final code = purchase['purchase_item_code']?.toString() ?? '';
                  final status = _status(purchase['purchase_item_status']?.toString());
                  final canConfirm = status == '거래 중';
                  final busy = _confirming.contains(code);
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: const BorderSide(color: Color(0xFFEAECF2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.shopping_bag_outlined, color: Color(0xFF6658E8)),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(status, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          TextButton(onPressed: () => _showDetails(purchase), child: const Text('상세')),
                        ]),
                        Text('상품 코드  ${purchase['sell_product_sell_product_code'] ?? ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF687083), fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('구매 코드  $code',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(_formatDate(purchase['purchase_item_date']?.toString() ?? ''),
                            style: const TextStyle(color: Color(0xFF858B9A), fontSize: 12)),
                        if (canConfirm) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: busy ? null : () => _confirmPurchase(purchase),
                              child: busy
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('구매 확정'),
                            ),
                          ),
                        ],
                      ]),
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 82, child: Text(label, style: const TextStyle(color: Color(0xFF858B9A)))),
          Expanded(child: SelectableText(value, textAlign: TextAlign.right)),
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

String _error(http.Response response, [Map<String, dynamic>? body]) =>
    (body ?? _decode(response))['detail']?.toString() ?? '구매 요청에 실패했습니다. (${response.statusCode})';

String _status(String? value) {
  final normalized = (value ?? '').trim();
  if (normalized == '거래중' || normalized == '거래 중') return '거래 중';
  if (normalized == '구매확정' || normalized == '구매 확정') return '구매 확정';
  if (normalized == '거래취소' || normalized == '거래 취소') return '거래 취소';
  return normalized.isEmpty ? '상태 확인 필요' : normalized;
}

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.replaceFirst('T', ' ');
  final date = parsed.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}
