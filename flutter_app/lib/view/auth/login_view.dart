import 'package:pokem_app/view/auth/recovery_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/view/auth/register_view.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});
  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _remember = false;
  bool _obscure = true;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ref
        .read(loginVmProvider.notifier)
        .login(_id.text, _password.text, remember: _remember);
  }

  Future<void> _openRegister() async {
    final id = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const RegisterView()));
    if (!mounted || id == null) return;
    _id.text = id;
    _password.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('회원가입이 완료되었습니다. 로그인해주세요.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginVmProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'POKEM / CARD & COLLECT',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 2,
                              color: const Color(0xFF657469),
                            ),
                          ),
                        ),
                        const SizedBox(height: 38),
                        Container(
                          width: 92,
                          height: 108,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5ECD8),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFC7D3B8)),
                          ),
                          child: Icon(
                            Icons.style_rounded,
                            size: 52,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '포켐',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '좋아하는 카드, 믿을 수 있는 거래',
                          style: TextStyle(color: Color(0xFF67716A)),
                        ),
                        const SizedBox(height: 38),
                        Form(
                          key: _form,
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '다시 만나서 반가워요',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                TextFormField(
                                  key: const Key('loginId'),
                                  controller: _id,
                                  enabled: !state.submitting,
                                  decoration: const InputDecoration(
                                    labelText: '아이디',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  autofillHints: const [AutofillHints.username],
                                  autocorrect: false,
                                  textInputAction: TextInputAction.next,
                                  validator: ref
                                      .read(loginVmProvider.notifier)
                                      .validateId,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  key: const Key('loginPassword'),
                                  controller: _password,
                                  enabled: !state.submitting,
                                  obscureText: _obscure,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: InputDecoration(
                                    labelText: '비밀번호',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: _obscure
                                          ? '비밀번호 표시'
                                          : '비밀번호 숨기기',
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) {
                                    if (!state.submitting) _submit();
                                  },
                                  validator: ref
                                      .read(loginVmProvider.notifier)
                                      .validatePassword,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          child: Checkbox(
                                            value: _remember,
                                            onChanged: state.submitting
                                                ? null
                                                : (value) => setState(
                                                    () => _remember = value!,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('자동로그인'),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: state.submitting
                                          ? null
                                          : () => Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    const RecoveryView(),
                                              ),
                                            ),
                                      child: const Text(
                                        '아이디 / 비밀번호 찾기',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                if (state.error != null)
                                  Container(
                                    key: const Key('loginError'),
                                    margin: const EdgeInsets.only(
                                      top: 10,
                                      bottom: 8,
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        state.error!,
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme
                                              .onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                FilledButton(
                                  key: const Key('loginSubmit'),
                                  onPressed: state.submitting ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(56),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: state.submitting
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          '로그인',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      '아직 포켐 회원이 아니신가요?',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF67716A),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: state.submitting
                                          ? null
                                          : _openRegister,
                                      child: const Text('회원가입'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          '카드의 가치를 함께 발견하는 곳',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A938A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
