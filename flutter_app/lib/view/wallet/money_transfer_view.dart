import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/model/wallet/wallet_models.dart';
import 'package:pokem_app/vm/wallet/money_transfer_vm.dart';
import 'package:pokem_app/view/wallet/wallet_view.dart';

class MoneyTransferView extends ConsumerStatefulWidget {
  const MoneyTransferView({super.key, required this.action});
  final MoneyAction action;
  @override
  ConsumerState<MoneyTransferView> createState() => _MoneyTransferViewState();
}

class _MoneyTransferViewState extends ConsumerState<MoneyTransferView> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _account;
  late final TextEditingController _amount;
  @override
  void initState() {
    super.initState();
    final state = ref.read(moneyTransferVmProvider(widget.action));
    _account = TextEditingController(text: state.account);
    _amount = TextEditingController(text: state.amount);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !ref.read(moneyTransferVmProvider(widget.action)).loading) {
        ref
            .read(moneyTransferVmProvider(widget.action).notifier)
            .refreshBalance();
      }
    });
  }

  @override
  void dispose() {
    _account.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final provider = moneyTransferVmProvider(action);
    final state = ref.watch(provider);
    final vm = ref.read(provider.notifier);
    ref.listen(provider.select((s) => s.amount), (_, amount) {
      if (_amount.text != amount) {
        _amount.value = TextEditingValue(
          text: amount,
          selection: TextSelection.collapsed(offset: amount.length),
        );
      }
    });
    return PopScope(
      canPop: !state.submitting,
      child: Scaffold(
        appBar: AppBar(title: Text('${action.label}하기')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('포켐머니 잔액'),
              const SizedBox(height: 8),
              Text(
                state.balance == null ? '잔액 확인 중' : formatWon(state.balance!),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              if (state.receipt != null) ...[
                Text(
                  action == MoneyAction.recharge
                      ? '충전이 완료되었습니다.'
                      : '환전 요청이 기록되었습니다.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  '${formatWon(state.receipt!.record.amount)} · 내역번호 ${state.receipt!.record.seq}',
                ),
                const SizedBox(height: 16),
                const Text('실제 결제나 은행 송금은 진행되지 않습니다.'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
                TextButton(
                  onPressed: () {
                    vm.newTransfer();
                    _account.clear();
                    _amount.clear();
                  },
                  child: Text('추가 ${action.label}'),
                ),
              ] else ...[
                TextFormField(
                  controller: _account,
                  enabled: !state.locked,
                  decoration: InputDecoration(
                    labelText: action == MoneyAction.recharge
                        ? '충전 계좌'
                        : '환전 계좌',
                    hintText: '은행명과 계좌번호',
                  ),
                  maxLength: 45,
                  validator: vm.validateAccount,
                  onChanged: vm.accountChanged,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  enabled: !state.locked,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: '${action.label} 금액',
                    suffixText: '원',
                  ),
                  validator: vm.validateAmount,
                  onChanged: vm.amountChanged,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final amount in [10000, 50000, 100000])
                      OutlinedButton(
                        onPressed: state.locked
                            ? null
                            : () => vm.addAmount(amount),
                        child: Text('+${formatWon(amount)}'),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('현재 실제 입출금은 연동되어 있지 않습니다. 요청하면 앱의 포켐머니 잔액에만 반영됩니다.'),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                if (state.uncertain) ...[
                  const Text(
                    '같은 요청을 다시 보내면 중복 처리될 수 있습니다. 내역 확인 전에는 다시 요청하지 마세요.',
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WalletView(),
                      ),
                    ),
                    child: const Text('충전·환전 내역 보기'),
                  ),
                ] else ...[
                  FilledButton(
                    onPressed:
                        state.submitting ||
                            state.loading ||
                            state.balance == null
                        ? null
                        : () async {
                            if (!_form.currentState!.validate()) return;
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('${action.label} 확인'),
                                content: Text(
                                  '${_account.text.trim()}\n${_amount.text}원을 ${action.label}하시겠습니까?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('취소'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('확인'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && mounted) await vm.submit();
                          },
                    child: Text(
                      state.submitting ? '처리 중' : '${action.label}하기',
                    ),
                  ),
                  TextButton(
                    onPressed: state.submitting || state.loading
                        ? null
                        : vm.refreshBalance,
                    child: const Text('잔액 새로고침'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
