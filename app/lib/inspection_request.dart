import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class InspectionRequestPage extends StatefulWidget {
  const InspectionRequestPage({super.key, required this.token});
  final String token;

  @override
  State<InspectionRequestPage> createState() => _InspectionRequestPageState();
}

class _InspectionRequestPageState extends State<InspectionRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '1');
  bool _loading = false;
  String? _requestNumber;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/inspection_request'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.token}'
            },
            body: jsonEncode({
              'inspection_request_amount':
                  int.parse(_amountController.text.trim())
            }),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data is Map<String, dynamic>) {
        setState(
            () => _requestNumber = data['inspection_request_no']?.toString());
      } else {
        final message =
            data is Map<String, dynamic> ? data['detail']?.toString() : null;
        _showMessage(message ?? '검수 신청에 실패했습니다.');
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
        appBar: AppBar(title: const Text('검수 신청')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  color: const Color(0xFFECEAFF),
                  borderRadius: BorderRadius.circular(20)),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_outlined,
                        color: Color(0xFF6658E8), size: 32),
                    SizedBox(height: 12),
                    Text('카드 검수 신청',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text('검수를 신청할 수량을 입력해 주세요.',
                        style: TextStyle(color: Color(0xFF666D7C))),
                  ]),
            ),
            const SizedBox(height: 24),
            if (_requestNumber != null)
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFFE5F5EC),
                    borderRadius: BorderRadius.circular(15)),
                child: Text('신청이 접수됐어요. 신청 번호: $_requestNumber',
                    style: const TextStyle(
                        color: Color(0xFF256B45), fontWeight: FontWeight.w600)),
              ),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: '검수 신청 수량',
                    suffixText: '개',
                    border: OutlineInputBorder()),
                validator: (value) {
                  final amount = int.tryParse(value?.trim() ?? '');
                  return amount == null || amount <= 0
                      ? '1 이상의 수량을 입력해 주세요.'
                      : null;
                },
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6658E8)),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('검수 신청하기'),
              ),
            ),
          ],
        ),
      );
}
