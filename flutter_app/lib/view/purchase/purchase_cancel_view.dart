import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/purchase/purchase_cancel_vm.dart';

class PurchaseCancelView extends ConsumerStatefulWidget {
  const PurchaseCancelView({super.key, required this.code});
  final String code;
  @override
  ConsumerState<PurchaseCancelView> createState() => _PurchaseCancelViewState();
}

class _PurchaseCancelViewState extends ConsumerState<PurchaseCancelView> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(purchaseCancelVmProvider(widget.code).notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('돌아가기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('확인'),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseCancelVmProvider(widget.code));
    final vm = ref.read(purchaseCancelVmProvider(widget.code).notifier);
    final snapshot = state.snapshot;
    final cancellation = snapshot?.cancellation;
    return PopScope(
      canPop: !state.busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('구매취소')),
        body: state.loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    SelectableText('구매번호 ${widget.code}'),
                    const SizedBox(height: 20),
                    if (snapshot != null) ...[
                      Text(
                        snapshot.purchase.title ??
                            snapshot.purchase.productCode,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (cancellation != null) ...[
                        Text('취소 상태 · ${cancellation.status}'),
                        const SizedBox(height: 12),
                        Text('신청 사유\n${cancellation.reason}'),
                        if (cancellation.responseReason?.isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 12),
                          Text('처리 사유\n${cancellation.responseReason}'),
                        ],
                        if (cancellation.status == '요청중')
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text('판매자 승인 후 결제 금액이 환불됩니다.'),
                          ),
                        if (cancellation.status == '철회')
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              '취소 신청을 철회했습니다. 구매내역에서 구매확정을 진행할 수 있습니다.',
                            ),
                          ),
                      ] else if (snapshot.canRequest &&
                          state.pending == null) ...[
                        const Text('취소 신청은 구매 건당 한 번만 가능합니다. 판매자 승인 후 환불됩니다.'),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _reason,
                          enabled: !state.busy,
                          maxLines: 4,
                          maxLength: 255,
                          validator: vm.validateReason,
                          decoration: const InputDecoration(labelText: '취소 사유'),
                        ),
                        FilledButton(
                          onPressed: state.busy
                              ? null
                              : () async {
                                  if (!_form.currentState!.validate()) return;
                                  if (await _confirm(
                                        '구매취소 신청',
                                        '판매자에게 취소를 요청하시겠습니까?',
                                      ) &&
                                      context.mounted) {
                                    await vm.request(_reason.text);
                                  }
                                },
                          child: Text(state.busy ? '처리 중' : '취소 신청하기'),
                        ),
                      ] else if (state.pending == null)
                        const Text('현재 상태에서는 구매취소를 신청할 수 없습니다.'),
                      if (cancellation?.status == '요청중' &&
                          state.pending == null)
                        OutlinedButton(
                          onPressed: state.busy
                              ? null
                              : () async {
                                  if (await _confirm(
                                        '취소 신청 철회',
                                        '취소 신청을 철회하시겠습니까? 같은 구매 건에는 다시 취소를 신청할 수 없습니다.',
                                      ) &&
                                      context.mounted) {
                                    await vm.withdraw();
                                  }
                                },
                          child: Text(state.busy ? '처리 중' : '취소 신청 철회'),
                        ),
                    ],
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
                    TextButton(
                      onPressed: state.busy ? null : () => vm.load(),
                      child: Text(state.pending != null ? '처리 상태 확인' : '새로고침'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
