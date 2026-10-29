import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'market_product.dart';

class RechargePage extends StatelessWidget {
  const RechargePage({
    super.key,
    required this.token,
    required this.userId,
    this.onBalanceChanged,
  });
  final String token;
  final String userId;
  final ValueChanged<int>? onBalanceChanged;

  @override
  Widget build(BuildContext context) => _WalletTransactionPage(
        token: token,
        userId: userId,
        kind: _TransactionKind.recharge,
        onBalanceChanged: onBalanceChanged,
      );
}

class ExchangePage extends StatelessWidget {
  const ExchangePage({super.key, required this.token, required this.userId});
  final String token;
  final String userId;

  @override
  Widget build(BuildContext context) => _WalletTransactionPage(
        token: token,
        userId: userId,
        kind: _TransactionKind.exchange,
      );
}

enum _TransactionKind { recharge, exchange }

class _WalletTransactionPage extends StatefulWidget {
  const _WalletTransactionPage({
    required this.token,
    required this.userId,
    required this.kind,
    this.onBalanceChanged,
  });
  final String token;
  final String userId;
  final _TransactionKind kind;
  final ValueChanged<int>? onBalanceChanged;

  @override
  State<_WalletTransactionPage> createState() => _WalletTransactionPageState();
}

class _WalletTransactionPageState extends State<_WalletTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _amountController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _records;
  bool _submitting = false;

  bool get _isRecharge => widget.kind == _TransactionKind.recharge;
  String get _title => _isRecharge ? '사이버머니 충전' : '사이버머니 환전';
  String get _path => _isRecharge ? 'recharge' : 'exchange';
  String get _amountKey => _isRecharge ? 'recharge_price' : 'exchange_price';
  String get _accountKey => _isRecharge ? 'recharge_account' : 'exchange_account';
  String get _dateKey => _isRecharge ? 'recharge_date' : 'exchange_date';
  String get _seqKey => _isRecharge ? 'recharge_seq' : 'exchange_seq';

  @override
  void initState() {
    super.initState();
    _records = _fetchRecords();
  }

  @override
  void dispose() {
    _accountController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      };

  Future<List<Map<String, dynamic>>> _fetchRecords() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/$_path'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception(_errorMessage(response));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw const FormatException('내역 응답 형식이 올바르지 않습니다.');
    return decoded.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> _refresh() async {
    final next = _fetchRecords();
    setState(() => _records = next);
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    final amount = int.parse(_amountController.text.replaceAll(',', ''));
    final body = <String, dynamic>{
      _amountKey: amount,
      _accountKey: _accountController.text.trim(),
    };
    if (_isRecharge) {
      body['user_user_id'] = widget.userId;
    } else {
      body['user_id'] = widget.userId;
    }
    setState(() => _submitting = true);
    try {
      final response = await http
          .post(Uri.parse('$apiBaseUrl/$_path'),
              headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_errorMessage(response));
      }
      final result = jsonDecode(utf8.decode(response.bodyBytes));
      if (!mounted) return;
      final balance = (result['user_money'] as num?)?.toInt();
      if (balance != null) widget.onBalanceChanged?.call(balance);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(balance == null
            ? (result['message']?.toString() ?? '요청이 완료되었습니다.')
            : '완료되었습니다. 현재 잔액 ${formatMarketPrice(balance)}원'),
      ));
      _amountController.clear();
      _accountController.clear();
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              _buildForm(),
              const SizedBox(height: 24),
              Text('$_title 내역',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _records,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _NoticeCard(
                      text: snapshot.error.toString().replaceFirst('Exception: ', ''),
                      action: TextButton(onPressed: _refresh, child: const Text('다시 불러오기')),
                    );
                  }
                  final records = snapshot.data ?? const [];
                  if (records.isEmpty) return const _NoticeCard(text: '아직 기록이 없습니다.');
                  return Column(
                    children: records.map((record) => _recordTile(record)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      );

  Widget _buildForm() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAECF2)),
        ),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_isRecharge ? '충전할 금액과 입금자명을 입력하세요.' : '환전 금액과 받을 계좌 정보를 입력하세요.',
                style: const TextStyle(color: Color(0xFF747887))),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '금액', suffixText: '원', border: OutlineInputBorder(),
              ),
              validator: (value) {
                final parsed = int.tryParse((value ?? '').replaceAll(',', '').trim());
                if (parsed == null || parsed < 1 || parsed > 2147483647) {
                  return '1원 이상의 금액을 입력하세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accountController,
              maxLength: 45,
              decoration: InputDecoration(
                labelText: _isRecharge ? '입금자명' : '환전 계좌 정보',
                hintText: _isRecharge ? '이름 또는 입금자명' : '은행명 / 계좌번호 / 예금주',
                border: const OutlineInputBorder(),
              ),
              validator: (value) => (value ?? '').trim().isEmpty ? '필수 입력 항목입니다.' : null,
            ),
            if (_isRecharge) ...[
              const SizedBox(height: 4),
              const Text('현재 서버 기능은 요청 시 사이버머니 잔액과 내역을 즉시 반영합니다.',
                  style: TextStyle(color: Color(0xFF858B9A), fontSize: 12)),
            ] else ...[
              const SizedBox(height: 4),
              const Text('환전 요청 시 잔액에서 금액이 즉시 차감되며, 실제 계좌 송금은 제공되지 않습니다.',
                  style: TextStyle(color: Color(0xFF858B9A), fontSize: 12)),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_title),
            ),
          ]),
        ),
      );

  Widget _recordTile(Map<String, dynamic> record) {
    final amount = (record[_amountKey] as num?)?.toInt() ?? 0;
    final account = record[_accountKey]?.toString() ?? '';
    final date = record[_dateKey]?.toString() ?? '';
    final seq = record[_seqKey]?.toString() ?? '';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFEAECF2)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _isRecharge ? const Color(0xFFE5F5EC) : const Color(0xFFECEAFF),
          child: Icon(_isRecharge ? Icons.add_rounded : Icons.swap_horiz_rounded,
              color: _isRecharge ? const Color(0xFF287D62) : const Color(0xFF6658E8)),
        ),
        title: Text('${_isRecharge ? '+' : '-'}${formatMarketPrice(amount)}원',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${_formatDate(date)}\n$account', maxLines: 2, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        trailing: Text('#$seq', style: const TextStyle(color: Color(0xFF858B9A), fontSize: 11)),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEAECF2)),
        ),
        child: Column(children: [Text(text, textAlign: TextAlign.center), if (action != null) action!]),
      );
}

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.replaceFirst('T', ' ');
  final date = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}

String _errorMessage(http.Response response) {
  try {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is Map && body['detail'] != null) return body['detail'].toString();
  } catch (_) {}
  return '요청에 실패했습니다. (${response.statusCode})';
}
