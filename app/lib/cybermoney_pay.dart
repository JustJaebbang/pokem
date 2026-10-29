import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'market_product.dart';

class CybermoneyPayPage extends StatefulWidget {
  const CybermoneyPayPage({super.key, required this.token});

  final String token;

  @override
  State<CybermoneyPayPage> createState() => _CybermoneyPayPageState();
}

class _CybermoneyPayPageState extends State<CybermoneyPayPage> {
  late Future<List<CybermoneyPayment>> _payments;

  @override
  void initState() {
    super.initState();
    _payments = _fetchPayments();
  }

  Future<List<CybermoneyPayment>> _fetchPayments() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/cybermoney_pay'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(_readError(response));
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('결제 내역 응답 형식이 올바르지 않습니다.');
    }
    return decoded
        .map((row) =>
            CybermoneyPayment.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> _refresh() async {
    final next = _fetchPayments();
    setState(() => _payments = next);
    try {
      await next;
    } catch (_) {
      // The page keeps its inline error state and retry action.
    }
  }

  Future<void> _openPayment(CybermoneyPayment payment) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CybermoneyPayDetailPage(
          token: widget.token,
          paymentCode: payment.code,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('결제 내역')),
        body: FutureBuilder<List<CybermoneyPayment>>(
          future: _payments,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _PaymentMessage(
                icon: Icons.wifi_off_rounded,
                title: '결제 내역을 불러오지 못했습니다.',
                detail:
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                actionLabel: '다시 불러오기',
                onAction: _refresh,
              );
            }
            final payments = snapshot.data ?? const <CybermoneyPayment>[];
            if (payments.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 150),
                    _PaymentMessage(
                      icon: Icons.receipt_long_outlined,
                      title: '결제 내역이 없습니다.',
                      detail: '상품을 구매하면 이곳에서 결제 정보를 확인할 수 있습니다.',
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                itemCount: payments.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        '구매 결제는 사이버머니에서 자동 차감됩니다.',
                        style: TextStyle(color: Color(0xFF747887)),
                      ),
                    );
                  }
                  final payment = payments[index - 1];
                  return _PaymentTile(
                    payment: payment,
                    onTap: () => _openPayment(payment),
                  );
                },
              ),
            );
          },
        ),
      );
}

class CybermoneyPayDetailPage extends StatefulWidget {
  const CybermoneyPayDetailPage(
      {super.key, required this.token, required this.paymentCode});

  final String token;
  final String paymentCode;

  @override
  State<CybermoneyPayDetailPage> createState() =>
      _CybermoneyPayDetailPageState();
}

class _CybermoneyPayDetailPageState extends State<CybermoneyPayDetailPage> {
  late Future<CybermoneyPayment> _payment;

  @override
  void initState() {
    super.initState();
    _payment = _fetchPayment();
  }

  Future<CybermoneyPayment> _fetchPayment() async {
    final code = Uri.encodeComponent(widget.paymentCode);
    final response = await http.get(
      Uri.parse('$apiBaseUrl/cybermoney_pay/$code'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(_readError(response));
    }
    return CybermoneyPayment.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> _retry() async {
    final next = _fetchPayment();
    setState(() => _payment = next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('결제 상세')),
        body: FutureBuilder<CybermoneyPayment>(
          future: _payment,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _PaymentMessage(
                icon: Icons.error_outline_rounded,
                title: '결제 정보를 불러오지 못했습니다.',
                detail:
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                actionLabel: '다시 시도',
                onAction: _retry,
              );
            }
            final payment = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEAFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.receipt_long_rounded,
                          color: Color(0xFF6658E8), size: 30),
                      const SizedBox(height: 18),
                      Text(
                        payment.isFailure
                            ? '실패 · ${formatMarketPrice(payment.price)}원'
                            : '-${formatMarketPrice(payment.price)}원',
                        style: const TextStyle(
                          color: Color(0xFF20283B),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(payment.displayStatus),
                        side: BorderSide.none,
                        backgroundColor: payment.statusBackground,
                        labelStyle: TextStyle(color: payment.statusForeground),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _PaymentInfoRow(
                    label: '결제 일시', value: _formatDate(payment.date)),
                _PaymentInfoRow(label: '결제 코드', value: payment.formattedCode),
                _PaymentInfoRow(
                  label: '구매 코드',
                  value: payment.purchaseCode,
                ),
                _PaymentInfoRow(label: '회원 ID', value: payment.userId),
              ],
            );
          },
        ),
      );
}

class CybermoneyPayment {
  const CybermoneyPayment({
    required this.code,
    required this.status,
    required this.date,
    required this.price,
    required this.purchaseCode,
    required this.userId,
  });

  final String code;
  final String status;
  final String date;
  final int price;
  final String purchaseCode;
  final String userId;

  String get displayStatus {
    final normalized = status.trim().toLowerCase();
    if ({'결제완료', '결제 성공', 'success', 'succeeded', 'paid'}
        .contains(normalized)) {
      return '결제 성공';
    }
    if ({'결제실패', '결제 실패', 'failure', 'failed', 'fail'}.contains(normalized)) {
      return '결제 실패';
    }
    return status;
  }

  bool get isFailure => displayStatus == '결제 실패';

  Color get statusForeground =>
      isFailure ? const Color(0xFFB4233A) : const Color(0xFF287D62);

  Color get statusBackground =>
      isFailure ? const Color(0xFFFFE9EC) : const Color(0xFFE5F5EC);

  String get formattedCode {
    final prefix = '${purchaseCode}_';
    if (!code.startsWith(prefix)) return code;
    final paymentDate = code.substring(prefix.length);
    return RegExp(r'^\d{20}$').hasMatch(paymentDate)
        ? '${purchaseCode}_$paymentDate'
        : code;
  }

  factory CybermoneyPayment.fromJson(Map<String, dynamic> json) =>
      CybermoneyPayment(
        code: (json['cybermoney_pay_code'] ?? '').toString(),
        status: (json['cybermoney_pay_status'] ?? '').toString(),
        date: (json['cybermoney_pay_date'] ?? '').toString(),
        price: (json['cybermoney_pay_price'] as num?)?.toInt() ??
            int.tryParse('${json['cybermoney_pay_price']}') ??
            0,
        purchaseCode:
            (json['purchase_item_purchase_item_code'] ?? '').toString(),
        userId: (json['user_user_id'] ?? '').toString(),
      );
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.onTap});

  final CybermoneyPayment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: payment.statusBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    payment.isFailure
                        ? Icons.error_outline_rounded
                        : Icons.shopping_bag_outlined,
                    color: payment.statusForeground,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(payment.displayStatus,
                          style: TextStyle(
                              color: payment.statusForeground,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(_formatDate(payment.date),
                          style: const TextStyle(
                              color: Color(0xFF858B9A), fontSize: 12)),
                      const SizedBox(height: 3),
                      Text('구매 코드 ${payment.purchaseCode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF858B9A), fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                        payment.isFailure
                            ? '${formatMarketPrice(payment.price)}원'
                            : '-${formatMarketPrice(payment.price)}원',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 3),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF9AA0AD), size: 19),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _PaymentInfoRow extends StatelessWidget {
  const _PaymentInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEAECF2)))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 86,
                child: Text(label,
                    style: const TextStyle(color: Color(0xFF858B9A)))),
            Expanded(
              child: SelectableText(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _PaymentMessage extends StatelessWidget {
  const _PaymentMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: const Color(0xFF9AA0AD)),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF858B9A))),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 10),
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
}

String _formatDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value.replaceFirst('T', ' ');
  final local = date.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String _readError(http.Response response) {
  try {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
      return decoded['detail'] as String;
    }
  } catch (_) {
    // Fall through to the HTTP status.
  }
  return '결제 내역 요청 실패 (${response.statusCode})';
}
