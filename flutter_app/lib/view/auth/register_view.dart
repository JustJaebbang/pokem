import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pokem_app/model/auth/register_input.dart';
import 'package:pokem_app/vm/auth/register_vm.dart';

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});
  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _nickname = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    for (final controller in [
      _id,
      _nickname,
      _name,
      _password,
      _confirm,
      _address,
      _phone,
      _email,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final id = await ref
        .read(registerVmProvider.notifier)
        .register(
          RegisterInput(
            id: _id.text,
            password: _password.text,
            confirmation: _confirm.text,
            nickname: _nickname.text,
            name: _name.text,
            phone: _phone.text,
            email: _email.text,
            address: _address.text,
          ),
        );
    if (!mounted || id == null) return;
    Navigator.of(context).pop(id);
  }

  Widget _field({
    required String keyName,
    required String label,
    required TextEditingController controller,
    int? maxLength,
    TextInputType? keyboard,
    int maxLines = 1,
    required RegisterField field,
    String? helper,
    bool password = false,
    bool last = false,
  }) {
    final submitting = ref.watch(registerVmProvider).submitting;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        key: Key(keyName),
        controller: controller,
        enabled: !submitting,
        maxLength: maxLength,
        maxLines: maxLines,
        keyboardType: keyboard,
        obscureText: password && _obscure,
        autocorrect: false,
        enableSuggestions: !password,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        onFieldSubmitted: last
            ? (_) {
                if (!submitting) _submit();
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          counterText: '',
          helperMaxLines: 3,
          suffixIcon: password && controller == _password
              ? IconButton(
                  tooltip: _obscure ? '비밀번호 표시' : '비밀번호 숨기기',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                )
              : null,
        ),
        validator: (value) => ref
            .read(registerVmProvider.notifier)
            .validateField(field, value, password: _password.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerVmProvider);
    final theme = Theme.of(context);
    return PopScope(
      canPop: !state.submitting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('회원가입'),
          automaticallyImplyLeading: !state.submitting,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Center(
              child: SizedBox(
                width: 440,
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '나만의 카드 여정을 시작해요',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '거래와 검수에 사용할 정보를 입력해주세요.',
                        style: TextStyle(color: Color(0xFF67716A)),
                      ),
                      const SizedBox(height: 28),
                      _field(
                        keyName: 'registerId',
                        field: RegisterField.id,
                        label: '아이디',
                        controller: _id,
                        maxLength: 20,
                        helper: '아이디 중복 여부는 가입 요청 시 확인합니다.',
                      ),
                      _field(
                        keyName: 'registerNickname',
                        field: RegisterField.nickname,
                        label: '닉네임',
                        controller: _nickname,
                        maxLength: 20,
                      ),
                      _field(
                        keyName: 'registerName',
                        field: RegisterField.name,
                        label: '이름',
                        controller: _name,
                        maxLength: 12,
                      ),
                      _field(
                        keyName: 'registerPassword',
                        field: RegisterField.password,
                        label: '비밀번호',
                        controller: _password,
                        password: true,
                      ),
                      _field(
                        keyName: 'registerConfirm',
                        field: RegisterField.confirmation,
                        label: '비밀번호 확인',
                        controller: _confirm,
                        password: true,
                      ),
                      _field(
                        keyName: 'registerAddress',
                        field: RegisterField.address,
                        label: '주소',
                        controller: _address,
                        maxLength: 255,
                        maxLines: 2,
                        helper: '도로명·건물번호와 상세주소를 함께 입력해주세요.',
                      ),
                      _field(
                        keyName: 'registerPhone',
                        field: RegisterField.phone,
                        label: '전화번호',
                        controller: _phone,
                        maxLength: 15,
                        keyboard: TextInputType.phone,
                        helper: '현재 단계에서는 문자 인증 없이 번호를 등록합니다.',
                      ),
                      _field(
                        keyName: 'registerEmail',
                        field: RegisterField.email,
                        label: '이메일',
                        controller: _email,
                        maxLength: 255,
                        keyboard: TextInputType.emailAddress,
                        last: true,
                      ),
                      if (state.error != null)
                        Container(
                          key: const Key('registerError'),
                          margin: const EdgeInsets.only(bottom: 16),
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
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ),
                      FilledButton(
                        key: const Key('registerSubmit'),
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
                                '가입하고 시작하기',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '가입 후 로그인 화면으로 돌아갑니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF67716A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
