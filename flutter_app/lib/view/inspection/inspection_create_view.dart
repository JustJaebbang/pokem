import 'package:pokem_app/core/formatters/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/inspection/inspection_create_vm.dart';

class InspectionCreateView extends ConsumerStatefulWidget {
  const InspectionCreateView({super.key});
  @override
  ConsumerState<InspectionCreateView> createState() =>
      _InspectionCreateViewState();
}

class _InspectionCreateViewState extends ConsumerState<InspectionCreateView> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionCreateVmProvider);
    final vm = ref.read(inspectionCreateVmProvider.notifier);
    return PopScope(
      canPop: !state.submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('검수신청')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (state.request != null) ...[
                const Icon(Icons.check_circle_outline, size: 64),
                const SizedBox(height: 20),
                Text(
                  '검수신청이 접수되었습니다.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SelectableText('신청번호 ${state.request!.number}'),
                const SizedBox(height: 8),
                Text('신청 수량 ${state.request!.amount ?? '-'}장'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('신청내역 보기'),
                ),
                TextButton(
                  onPressed: () {
                    vm.newRequest();
                    _amount.clear();
                  },
                  child: const Text('추가 신청'),
                ),
              ] else ...[
                Text(
                  '검수할 카드 수량',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text('검수를 맡길 카드의 수량을 입력해주세요.'),
                const SizedBox(height: 8),
                const Text('검수비는 카드 1장당 10,000원입니다.'),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _amount,
                  enabled: !state.locked,
                  decoration: const InputDecoration(
                    labelText: '카드 수량',
                    suffixText: '장',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: vm.validateAmount,
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _amount,
                  builder: (_, value, _) {
                    final price = vm.estimatedPrice(value.text);
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        price == null
                            ? '수량을 입력하면 총 검수비가 표시됩니다.'
                            : '총 검수비 ${formatWon(price)}',
                      ),
                    );
                  },
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                if (state.uncertain)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('신청내역 확인'),
                  )
                else
                  FilledButton(
                    onPressed: state.submitting
                        ? null
                        : () {
                            if (_form.currentState!.validate()) {
                              vm.submit(_amount.text);
                            }
                          },
                    child: Text(state.submitting ? '신청 중' : '신청하기'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
