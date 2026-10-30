import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'pay_history.dart';

class InspectionRequestPage extends StatefulWidget {
  const InspectionRequestPage({super.key, required this.token});
  final String token;

  @override
  State<InspectionRequestPage> createState() => _InspectionRequestPageState();
}

class _InspectionRequestPageState extends State<InspectionRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '1');
  late Future<List<Map<String, dynamic>>> _requests;
  bool _loading = false;
  String? _createdRequestNo;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    _requests = _fetchRequests();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchRequests() async {
    final response = await http
        .get(Uri.parse('$apiBaseUrl/inspection_request'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception(_readError(response));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('검수 신청 내역 응답 형식이 올바르지 않습니다.');
    }
    return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> _refresh() async {
    final next = _fetchRequests();
    setState(() => _requests = next);
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) return;
    setState(() => _loading = true);
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/inspection_request'),
            headers: _headers,
            body: jsonEncode({
              'inspection_request_amount':
                  int.parse(_amountController.text.trim()),
            }),
          )
          .timeout(const Duration(seconds: 15));
      final data = _decode(response);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_readError(response, data));
      }
      final requestNo = data['inspection_request_no']?.toString();
      if (requestNo == null || requestNo.isEmpty) {
        throw const FormatException('서버 응답에 검수 신청 번호가 없습니다.');
      }
      if (!mounted) return;
      setState(() => _createdRequestNo = requestNo);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('검수 신청이 접수되었습니다. 신청 번호 $requestNo')),
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showDetails(String requestNo) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '$apiBaseUrl/inspection_request/${Uri.encodeComponent(requestNo)}'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw Exception(_readError(response));
      final request = _decode(response);
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
                const Text('검수 신청 상세',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _RequestDetailRow(
                    label: '신청 번호',
                    value: request['inspection_request_no']?.toString() ??
                        requestNo),
                _RequestDetailRow(
                    label: '신청 일시',
                    value: _formatDate(
                        request['inspection_request_date']?.toString() ?? '')),
                _RequestDetailRow(
                    label: '신청 수량',
                    value:
                        '${request['inspection_request_amount'] ?? ''}개'),
                _RequestDetailRow(
                    label: '담당 매니저',
                    value: request['manager_manager_id']?.toString() ??
                        '미배정'),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('검수 신청')),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _buildIntro(),
              const SizedBox(height: 18),
              _buildForm(),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => PayHistoryPage(token: widget.token),
                    ),
                  ),
                  icon: const Icon(Icons.payment_rounded),
                  label: const Text('검수 결제 내역'),
                ),
              ),
              if (_createdRequestNo != null) ...[
                const SizedBox(height: 12),
                _CreatedRequestCard(requestNo: _createdRequestNo!),
              ],
              const SizedBox(height: 26),
              const Text('신청 내역',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _requests,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _RequestNotice(
                      message: snapshot.error
                          .toString()
                          .replaceFirst('Exception: ', ''),
                      action: TextButton(
                          onPressed: _refresh,
                          child: const Text('다시 불러오기')),
                    );
                  }
                  final requests = snapshot.data ?? const [];
                  if (requests.isEmpty) {
                    return const _RequestNotice(message: '아직 검수 신청 내역이 없습니다.');
                  }
                  return Column(
                    children: requests
                        .map((request) => _RequestTile(
                              request: request,
                              onTap: () => _showDetails(
                                request['inspection_request_no'].toString(),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      );

  Widget _buildIntro() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFECEAFF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_outlined,
                color: Color(0xFF6658E8), size: 32),
            SizedBox(height: 11),
            Text('카드 검수 신청',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 5),
            Text('검수를 신청할 카드 수량을 입력해 주세요.',
                style: TextStyle(color: Color(0xFF666D7C))),
          ],
        ),
      );

  Widget _buildForm() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAECF2)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '검수 신청 수량',
                  suffixText: '개',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = int.tryParse(value?.trim() ?? '');
                  if (amount == null || amount < 1 || amount > 2147483647) {
                    return '1개 이상의 수량을 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6658E8)),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('검수 신청하기'),
              ),
            ],
          ),
        ),
      );
}

class _CreatedRequestCard extends StatelessWidget {
  const _CreatedRequestCard({required this.requestNo});
  final String requestNo;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE5F5EC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('최근 접수된 신청',
              style: TextStyle(
                  color: Color(0xFF256B45), fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          SelectableText('신청 번호  $requestNo',
              style: const TextStyle(
                  color: Color(0xFF256B45), fontWeight: FontWeight.w600)),
          if (RegExp(r'^\d{14}$').hasMatch(requestNo)) ...[
            const SizedBox(height: 3),
            Text('신청일 ${requestNo.substring(0, 8)} · 순번 ${requestNo.substring(8)}',
                style: const TextStyle(color: Color(0xFF438064), fontSize: 12)),
          ],
        ]),
      );
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request, required this.onTap});
  final Map<String, dynamic> request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final requestNo = request['inspection_request_no']?.toString() ?? '';
    final amount = (request['inspection_request_amount'] as num?)?.toInt() ?? 0;
    final manager = request['manager_manager_id']?.toString();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFEAECF2)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFECEAFF),
          child: Icon(Icons.fact_check_outlined, color: Color(0xFF6658E8)),
        ),
        title: Text('$amount개 검수 신청',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${_formatDate(request['inspection_request_date']?.toString() ?? '')}\n신청 번호 $requestNo',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        trailing: Icon(
          manager == null || manager.isEmpty
              ? Icons.hourglass_top_rounded
              : Icons.check_circle_outline_rounded,
          color: manager == null || manager.isEmpty
              ? const Color(0xFFB7791F)
              : const Color(0xFF287D62),
        ),
      ),
    );
  }
}

class _RequestDetailRow extends StatelessWidget {
  const _RequestDetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(color: Color(0xFF858B9A)))),
          Expanded(
              child: SelectableText(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class _RequestNotice extends StatelessWidget {
  const _RequestNotice({required this.message, this.action});
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
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return <String, dynamic>{};
}

String _readError(http.Response response, [Map<String, dynamic>? body]) =>
    (body ?? _decode(response))['detail']?.toString() ??
    '요청에 실패했습니다. (${response.statusCode})';

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.replaceFirst('T', ' ');
  final date = parsed.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}
