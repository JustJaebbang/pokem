import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _nickname = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _nickname.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/user'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': _id.text.trim(),
              'user_password': _password.text,
              'user_nickname': _nickname.text.trim(),
              'user_name': _name.text.trim(),
              'user_phone': _phone.text.trim(),
              'user_email': _email.text.trim(),
              'user_address': _address.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      String message = '회원가입에 실패했습니다. 입력 내용을 확인해 주세요.';
      try {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic> && data['detail'] is String) {
          message = data['detail'] as String;
        }
      } catch (_) {
        // 응답이 JSON이 아니면 기본 안내 문구를 보여줍니다.
      }
      _showMessage(message);
    } catch (_) {
      _showMessage('서버에 연결할 수 없습니다. API 주소와 서버 상태를 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String? _required(String? value, String label) {
    return value == null || value.trim().isEmpty ? '$label 입력해 주세요.' : null;
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8EAF1))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF6658E8), width: 1.5)),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscure = false,
    VoidCallback? toggleObscure,
    TextInputAction? action,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: action,
          obscureText: obscure,
          validator: validator,
          decoration: _decoration(label, icon).copyWith(
            suffixIcon: toggleObscure == null
                ? null
                : IconButton(
                    onPressed: toggleObscure,
                    icon: Icon(obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                  ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
                children: [
                  const Text('PoKeM의 새 계정을 만들라옹.',
                      style: TextStyle(fontSize: 15, color: Color(0xFF7C8394))),
                  const SizedBox(height: 22),
                  _field(
                      controller: _id,
                      label: '아이디',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => _required(v, '아이디를'),
                      action: TextInputAction.next),
                  _field(
                    controller: _password,
                    label: '비밀번호 (8자 이상)',
                    icon: Icons.lock_outline_rounded,
                    obscure: _hidePassword,
                    toggleObscure: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    validator: (v) => v == null || v.length < 8
                        ? '비밀번호를 8자 이상 입력해달라옹.'
                        : null,
                    action: TextInputAction.next,
                  ),
                  _field(
                    controller: _passwordConfirm,
                    label: '비밀번호 확인한다옹',
                    icon: Icons.lock_reset_rounded,
                    obscure: _hideConfirmation,
                    toggleObscure: () =>
                        setState(() => _hideConfirmation = !_hideConfirmation),
                    validator: (v) =>
                        v != _password.text ? '비밀번호가 일치하지 않다옹.' : null,
                    action: TextInputAction.next,
                  ),
                  _field(
                      controller: _nickname,
                      label: '닉네임',
                      icon: Icons.badge_outlined,
                      validator: (v) => _required(v, '닉네임을'),
                      action: TextInputAction.next),
                  _field(
                      controller: _name,
                      label: '이름',
                      icon: Icons.person_rounded,
                      validator: (v) => _required(v, '이름을'),
                      action: TextInputAction.next),
                  _field(
                      controller: _phone,
                      label: '전화번호',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) => _required(v, '전화번호를'),
                      action: TextInputAction.next),
                  _field(
                      controller: _email,
                      label: '이메일',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return '이메일을 입력해 주세요.';
                        }
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(v.trim())) {
                          return '이메일 주소를 확인해 주세요.';
                        }
                        return null;
                      },
                      action: TextInputAction.next),
                  _field(
                      controller: _address,
                      label: '주소',
                      icon: Icons.home_outlined,
                      validator: (v) => _required(v, '주소를'),
                      action: TextInputAction.done),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6658E8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15))),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('가입하기',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
