import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/auth/recovery_vm.dart';

class RecoveryView extends ConsumerStatefulWidget {
  const RecoveryView({super.key});
  @override
  ConsumerState<RecoveryView> createState() => _RecoveryViewState();
}

class _RecoveryViewState extends ConsumerState<RecoveryView> {
  RecoveryPurpose _purpose = RecoveryPurpose.findId;
  final _email = TextEditingController(),
      _id = TextEditingController(),
      _code = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController();
  @override
  void dispose() {
    for (final c in [_email, _id, _code, _password, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recoveryVmProvider(_purpose));
    final vm = ref.read(recoveryVmProvider(_purpose).notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('계정 찾기')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SegmentedButton<RecoveryPurpose>(
            segments: [
              for (final p in RecoveryPurpose.values)
                ButtonSegment(value: p, label: Text(p.label)),
            ],
            selected: {_purpose},
            onSelectionChanged: state.busy
                ? null
                : (values) => setState(() {
                    _purpose = values.single;
                    _code.clear();
                    _password.clear();
                    _confirmation.clear();
                  }),
          ),
          const SizedBox(height: 24),
          if (state.result != null) ...[
            Text(state.result!.message),
            for (final id in state.result!.ids)
              ListTile(title: SelectableText(id)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('로그인으로 돌아가기'),
            ),
          ] else ...[
            const Text('가입할 때 사용한 이메일 주소로 인증번호를 보내드립니다.'),
            const SizedBox(height: 20),
            if (_purpose == RecoveryPurpose.resetPassword) ...[
              TextField(
                controller: _id,
                enabled: !state.busy && state.challenge == null,
                decoration: const InputDecoration(labelText: '아이디'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _email,
              enabled: !state.busy && state.challenge == null,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: '가입 이메일'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: state.busy || state.resendIn > 0
                  ? null
                  : () {
                      FocusScope.of(context).unfocus();
                      _code.clear();
                      vm.request(_email.text, _id.text);
                    },
              child: Text(
                state.resendIn > 0
                    ? '다시 보내기 (${state.resendIn}초)'
                    : state.challenge == null
                    ? '인증번호 받기'
                    : '인증번호 다시 받기',
              ),
            ),
            if (state.challenge != null) ...[
              const SizedBox(height: 12),
              const Text(
                '일치하는 가입 정보가 있으면 메일을 보냈습니다. 메일이 없다면 스팸함과 입력한 가입 정보를 확인해주세요.',
              ),
              TextButton(
                onPressed: state.busy
                    ? null
                    : () {
                        ref.invalidate(recoveryVmProvider(_purpose));
                        _code.clear();
                        _password.clear();
                        _confirmation.clear();
                      },
                child: const Text('이메일·아이디 다시 입력'),
              ),
              TextField(
                controller: _code,
                enabled: !state.busy,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: '인증번호',
                  helperText: state.secondsLeft > 0
                      ? '남은 시간 ${state.secondsLeft ~/ 60}:${(state.secondsLeft % 60).toString().padLeft(2, '0')}'
                      : '인증번호가 만료되었습니다.',
                ),
              ),
              if (_purpose == RecoveryPurpose.resetPassword) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  enabled: !state.busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: '새 비밀번호',
                    helperText: '8~128자',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmation,
                  enabled: !state.busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: state.busy || state.secondsLeft <= 0
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        vm.complete(
                          _code.text,
                          _password.text,
                          _confirmation.text,
                        );
                      },
                child: Text(
                  _purpose == RecoveryPurpose.findId ? '아이디 확인' : '비밀번호 변경',
                ),
              ),
            ],
            if (state.busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (state.error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
