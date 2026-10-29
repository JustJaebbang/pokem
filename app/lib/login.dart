import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'home.dart';
import 'signup.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/auth/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'login_id': _idController.text.trim(),
              'password': _passwordController.text
            }),
          )
          .timeout(const Duration(seconds: 15));
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        navigator.pushReplacement(MaterialPageRoute<void>(
          builder: (_) => HomePage(
            token: data['access_token'] as String,
            role: data['role'] as String,
            account: Map<String, dynamic>.from(data['account'] as Map),
            onLogout: () => navigator.pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const LoginPage()),
              (_) => false,
            ),
          ),
        ));
      } else {
        final detail = data['detail'];
        _showMessage(detail is String ? detail : '아이디 또는 비밀번호를 확인해 주세요.');
      }
    } catch (_) {
      _showMessage('서버에 연결할 수 없습니다. API 주소와 서버 실행 상태를 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 94,
                        width: 94,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: const Color(0xFFECEAFF),
                            borderRadius: BorderRadius.circular(30)),
                        child: const Icon(Icons.catching_pokemon_rounded,
                            size: 56, color: Color(0xFF6658E8)),
                      ),
                      const SizedBox(height: 28),
                      const Text('포켓몬 카드마켓',
                          style: TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF20283B))),
                      const SizedBox(height: 8),
                      const Text('좋아하는 카드를 찾고, 안전하게 거래해요.',
                          style: TextStyle(
                              fontSize: 15, color: Color(0xFF7C8394))),
                      const SizedBox(height: 38),
                      const Text('로그인',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _idController,
                        textInputAction: TextInputAction.next,
                        decoration:
                            _decoration('아이디', Icons.person_outline_rounded),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? '아이디를 입력해 주세요.'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onFieldSubmitted: (_) => _login(),
                        decoration:
                            _decoration('비밀번호', Icons.lock_outline_rounded)
                                .copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? '비밀번호를 입력해 주세요.'
                            : null,
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed: _loading ? null : _login,
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF6658E8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16))),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('로그인',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('일반 회원과 관리자 계정 모두 로그인할 수 있어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFF858B9A), fontSize: 13)),
                      const SizedBox(height: 20),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('아직 계정이 없으신가요?',
                                style: TextStyle(color: Color(0xFF737A8A))),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () async {
                                      final created =
                                          await Navigator.of(context)
                                              .push<bool>(
                                        MaterialPageRoute<bool>(
                                            builder: (_) => const SignupPage()),
                                      );
                                      if (created == true && mounted) {
                                        _showMessage('회원가입이 완료됐어요. 로그인해 주세요.');
                                      }
                                    },
                              child: const Text('회원가입',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ]),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFE8EAF1))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF6658E8), width: 1.5)),
      );
}
