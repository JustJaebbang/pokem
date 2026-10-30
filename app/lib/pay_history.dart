import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'market_product.dart';

class PayHistoryPage extends StatefulWidget {
  const PayHistoryPage({super.key, required this.token});
  final String token;

  @override
  State<PayHistoryPage> createState() => _PayHistoryPageState();
}

class _PayHistoryPageState extends State<PayHistoryPage> {
  late Future<List<Map<String, dynamic>>> _payments;

  @override
  void initState() {
    super.initState();
    _payments = _fetchPayments();
  }

  Future<List<Map<String, dynamic>>> _fetchPayments() async {
    final uri = Uri.parse('$apiBaseUrl/pay').replace(
      queryParameters: const {'limit': '100', 'offset': '0'},
    );
    final response = await http.get(uri, headers: _authHeaders).timeout(
          const Duration(seconds: 15),
        );
    if (response.statusCode != 200) throw Exception(_error(response));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw const FormatException('결제 내역 응답 형식이 올바르지 않습니다.');
    return decoded.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Map<String, String> get _authHeaders =>
      {'Authorization': 'Bearer ${widget.token}'};

  Future<void> _refresh() async {
    final next = _fetchPayments();
    setState(() => _payments = next);
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _showDetails(String payNo) async {
    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/pay/${Uri.encodeComponent(payNo)}'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw Exception(_error(response));
      final payment = _decode(response);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('검수 결제 상세',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _PayDetailRow(
                    label: '결제 번호',
                    value: payment['pay_no']?.toString() ?? payNo),
                _PayDetailRow(
                    label: '검수 신청 번호',
                    value: payment['inspection_request_inspection_request_no']
                            ?.toString() ??
                        ''),
                _PayDetailRow(
                    label: '결제 일시',
                    value: _formatDate(payment['pay_date']?.toString() ?? '')),
                _PayDetailRow(
                    label: '결제 금액',
                    value: _amountText(payment['pay_price'])),
                _PayDetailRow(
                    label: '결제 상태',
                    value: payment['pay_status']?.toString() ?? '상태 확인 필요'),
                _PayDetailRow(
                    label: '담당 매니저',
                    value: payment['manager_manager_id']?.toString() ?? ''),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String text) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('검수 결제 내역')),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _payments,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 260),
                    Center(child: CircularProgressIndicator()),
                  ],
                );
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 180),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        snapshot.error
                            .toString()
                            .replaceFirst('Exception: ', ''),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Center(
                      child: TextButton(
                          onPressed: _refresh,
                          child: const Text('다시 불러오기')),
                    ),
                  ],
                );
              }
              final payments = snapshot.data ?? const [];
              if (payments.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  children: const [
                    SizedBox(height: 110),
                    Icon(Icons.receipt_long_outlined,
                        size: 44, color: Color(0xFF9AA0AD)),
                    SizedBox(height: 12),
                    Center(child: Text('결제 내역이 없습니다.')),
                    SizedBox(height: 12),
                    _PaymentInfoNotice(),
                  ],
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: payments.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  if (index == 0) return const _PaymentInfoNotice();
                  final payment = payments[index - 1];
                  return _PayTile(
                    payment: payment,
                    onTap: () => _showDetails(
                        payment['pay_no']?.toString() ?? ''),
                  );
                },
              );
            },
          ),
        ),
      );
}

class _PayTile extends StatelessWidget {
  const _PayTile({required this.payment, required this.onTap});
  final Map<String, dynamic> payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = payment['pay_status']?.toString() ?? '상태 확인 필요';
    final payNo = payment['pay_no']?.toString() ?? '';
    final price = payment['pay_price'];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Color(0xFFEAECF2)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFECEAFF),
          child: Icon(Icons.payment_rounded, color: Color(0xFF6658E8)),
        ),
        title: Text(_amountText(price),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '$status · ${_formatDate(payment['pay_date']?.toString() ?? '')}\n결제 번호 $payNo',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _PaymentInfoNotice extends StatelessWidget {
  const _PaymentInfoNotice();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '검수 결제 내역은 매니저가 검수 신청을 배정한 뒤 표시됩니다. 이 화면은 API가 제공하는 결제 내역을 조회합니다.',
          style: TextStyle(color: Color(0xFF747887), fontSize: 12),
        ),
      );
}

class _PayDetailRow extends StatelessWidget {
  const _PayDetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 100,
              child: Text(label, style: const TextStyle(color: Color(0xFF858B9A)))),
          Expanded(
              child: SelectableText(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

String _amountText(Object? value) {
  final amount = (value as num?)?.toInt();
  if (amount == null) return '금액 확인 중';
  return '${formatMarketPrice(amount)}원';
}

Map<String, dynamic> _decode(http.Response response) {
  try {
    final value = jsonDecode(utf8.decode(response.bodyBytes));
    if (value is Map<String, dynamic>) return value;
  } catch (_) {}
  return <String, dynamic>{};
}

String _error(http.Response response) {
  try {
    final body = _decode(response);
    if (body['detail'] != null) return body['detail'].toString();
  } catch (_) {}
  return '결제 내역 요청에 실패했습니다. (${response.statusCode})';
}

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.replaceFirst('T', ' ');
  final date = parsed.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}
