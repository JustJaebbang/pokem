import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class UserAccountPage extends StatelessWidget {
  const UserAccountPage({
    super.key,
    required this.account,
    required this.token,
    this.onLogout,
  });

  final Map<String, dynamic> account;
  final String token;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final userId = account['user_id']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('회원 정보 관리')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _AccountAction(
            icon: Icons.edit_outlined,
            title: '회원 정보 수정',
            subtitle: '연락처, 이메일, 주소 변경',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => _EditUserPage(
                  account: account,
                  token: token,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _AccountAction(
            icon: Icons.person_remove_outlined,
            title: '회원 탈퇴',
            subtitle: '탈퇴 사유를 남기고 계정을 삭제합니다',
            destructive: true,
            onTap: () => _confirmQuit(context, userId),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmQuit(BuildContext context, String userId) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('탈퇴하면 계정이 삭제되고 되돌릴 수 없습니다. 계속할까요?'),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '탈퇴 사유 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB4233A)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      reasonController.dispose();
      return;
    }
    try {
      final response = await http
          .delete(
            Uri.parse('$apiBaseUrl/user/${Uri.encodeComponent(userId)}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'quit_reason': reasonController.text.trim()}),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = _decodeResponse(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_readError(decoded, response.statusCode));
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(decoded['message']?.toString() ?? '탈퇴가 완료되었습니다.')),
      );
      onLogout?.call();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      reasonController.dispose();
    }
  }
}

class _EditUserPage extends StatefulWidget {
  const _EditUserPage({required this.account, required this.token});
  final Map<String, dynamic> account;
  final String token;

  @override
  State<_EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<_EditUserPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.account['user_phone']?.toString() ?? '');
    _email = TextEditingController(text: widget.account['user_email']?.toString() ?? '');
    _address = TextEditingController(text: widget.account['user_address']?.toString() ?? '');
  }

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final userId = widget.account['user_id'].toString();
      final response = await http
          .put(
            Uri.parse('$apiBaseUrl/user/${Uri.encodeComponent(userId)}'),
            headers: {
              'Authorization': 'Bearer ${widget.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'user_phone': _phone.text.trim(),
              'user_email': _email.text.trim(),
              'user_address': _address.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = _decodeResponse(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_readError(decoded, response.statusCode));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('회원 정보가 수정되었습니다.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('회원 정보 수정')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '전화번호', border: OutlineInputBorder()),
                validator: _required,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '이메일', border: OutlineInputBorder()),
                validator: (value) {
                  final requiredError = _required(value);
                  if (requiredError != null) return requiredError;
                  if (!(value ?? '').contains('@')) return '이메일 주소를 확인하세요.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '주소', border: OutlineInputBorder()),
                validator: _required,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('저장'),
              ),
            ],
          ),
        ),
      );

  String? _required(String? value) => (value ?? '').trim().isEmpty ? '필수 입력 항목입니다.' : null;
}

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: Color(0xFFEAECF2)),
        ),
        child: ListTile(
          leading: Icon(icon, color: destructive ? const Color(0xFFB4233A) : const Color(0xFF6658E8)),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: destructive ? const Color(0xFFB4233A) : null)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}

Map<String, dynamic> _decodeResponse(http.Response response) {
  try {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return <String, dynamic>{};
}

String _readError(Map<String, dynamic> body, int status) =>
    body['detail']?.toString() ?? '요청에 실패했습니다. ($status)';
