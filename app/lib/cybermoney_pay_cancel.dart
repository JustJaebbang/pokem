import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'market_product.dart';

class CybermoneyPayCancelPage extends StatefulWidget {
  const CybermoneyPayCancelPage({super.key, required this.token});

  final String token;

  @override
  State<CybermoneyPayCancelPage> createState() => _CybermoneyPayCancelPageState();
}

class _CybermoneyPayCancelPageState extends State<CybermoneyPayCancelPage> {
  late Future<List<_RefundRecord>> _records;

  @override
  void initState() {
    super.initState();
    _records = _fetch();
  }

  Future<List<_RefundRecord>> _fetch() async {
    final headers = {'Authorization': 'Bearer ${widget.token}'};
    final responses = await Future.wait([
      http.get(Uri.parse('$apiBaseUrl/purchase_cancel'), headers: headers),
      http.get(Uri.parse('$apiBaseUrl/cybermoney_pay'), headers: headers),
    ]).timeout(const Duration(seconds: 15));
    for (final response in responses) {
      if (response.statusCode != 200) throw Exception(_apiError(response));
    }
    final cancels = jsonDecode(utf8.decode(responses[0].bodyBytes));
    final payments = jsonDecode(utf8.decode(responses[1].bodyBytes));
    if (cancels is! List || payments is! List) {
      throw const FormatException('Invalid refund history response.');
    }
    final paymentByPurchase = <String, Map<String, dynamic>>{};
    for (final item in payments.whereType<Map>()) {
      final row = Map<String, dynamic>.from(item);
      paymentByPurchase[row['purchase_item_purchase_item_code']?.toString() ?? ''] = row;
    }
    return cancels.whereType<Map>().map((item) {
      final cancel = Map<String, dynamic>.from(item);
      final purchaseCode = cancel['purchase_item_purchase_item_code']?.toString() ?? '';
      return _RefundRecord(
        cancel: cancel,
        payment: paymentByPurchase[purchaseCode],
      );
    }).where((record) => record.cancel['purchase_cancel_status']?.toString() == '\u{c2b9}\u{c778}' && record.payment != null).toList();
  }

  Future<void> _refresh() async {
    final next = _fetch();
    setState(() => _records = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('\u{acb0}\u{c81c} \u{cde8}\u{c18c}/\u{d658}\u{ae09}')),
        body: FutureBuilder<List<_RefundRecord>>(
          future: _records,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _RefundState(
                icon: Icons.wifi_off_rounded,
                title: '\u{d658}\u{ae09} \u{b0b4}\u{c5ed}\u{c744} \u{bd88}\u{b7ec}\u{c624}\u{c9c0} \u{babb}\u{d588}\u{c5b4}\u{c694}.',
                detail: snapshot.error.toString().replaceFirst('Exception: ', ''),
                onRetry: _refresh,
              );
            }
            final records = snapshot.data ?? const <_RefundRecord>[];
            if (records.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 150),
                    _RefundState(
                      icon: Icons.receipt_long_outlined,
                      title: '\u{d658}\u{ae09} \u{b0b4}\u{c5ed}\u{c774} \u{c5c6}\u{c5b4}\u{c694}.',
                      detail: '\u{ad6c}\u{b9e4} \u{cde8}\u{c18c} \u{c2b9}\u{c778} \u{d6c4} \u{c0ac}\u{c774}\u{bc84}\u{ba38}\u{b2c8} \u{d658}\u{ae09} \u{b0b4}\u{c5ed}\u{c774} \u{d45c}\u{c2dc}\u{b429}\u{b2c8}\u{b2e4}.',
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _RefundTile(record: records[index]),
              ),
            );
          },
        ),
      );
}

class _RefundRecord {
  const _RefundRecord({required this.cancel, required this.payment});
  final Map<String, dynamic> cancel;
  final Map<String, dynamic>? payment;
}

class _RefundTile extends StatelessWidget {
  const _RefundTile({required this.record});
  final _RefundRecord record;

  @override
  Widget build(BuildContext context) {
    final cancel = record.cancel;
    final payment = record.payment!;
    final amount = (payment['cybermoney_pay_price'] as num?)?.toInt() ?? int.tryParse('${payment['cybermoney_pay_price']}') ?? 0;
    final paymentCode = payment['cybermoney_pay_code']?.toString() ?? '';
    final cancelDate = cancel['responded_at']?.toString() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF287D62)),
            const SizedBox(width: 9),
            const Expanded(child: Text('\u{d658}\u{ae09} \u{c644}\u{b8cc}', style: TextStyle(fontWeight: FontWeight.w700))),
            Text('+${formatMarketPrice(amount)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF287D62))),
          ]),
          const Divider(height: 24),
          _RefundRow(label: '\u{ad6c}\u{b9e4} \u{cf54}\u{b4dc}', value: cancel['purchase_item_purchase_item_code']?.toString() ?? ''),
          _RefundRow(label: '\u{acb0}\u{c81c} \u{cf54}\u{b4dc}', value: paymentCode),
          _RefundRow(label: '\u{cde8}\u{c18c} \u{c2b9}\u{c778}\u{c77c}', value: cancelDate),
          _RefundRow(label: 'cybermoney_pay_cancel_code', value: '\u{c11c}\u{bc84} API\u{ac00} \u{cf54}\u{b4dc}\u{b97c} \u{bc18}\u{d658}\u{d558}\u{c9c0} \u{c54a}\u{c74c}'),
        ]),
      ),
    );
  }
}

class _RefundRow extends StatelessWidget {
  const _RefundRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 128, child: Text(label, style: const TextStyle(color: Color(0xFF777D8A), fontSize: 12))),
          Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      );
}

class _RefundState extends StatelessWidget {
  const _RefundState({required this.icon, required this.title, required this.detail, this.onRetry});
  final IconData icon;
  final String title;
  final String detail;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 42, color: const Color(0xFF9AA0AD)),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF737A8A))),
            if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('\u{b2e4}\u{c2dc} \u{c2dc}\u{b3c4}')),
          ]),
        ),
      );
}

String _apiError(http.Response response) {
  try {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is Map && body['detail'] != null) return body['detail'].toString();
  } catch (_) {}
  return 'HTTP ${response.statusCode}';
}
