import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/vm/purchase/purchase_confirm_vm.dart';

class PurchaseConfirmAction extends ConsumerWidget {
  const PurchaseConfirmAction({super.key, required this.purchase});
  final Purchase purchase;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = purchaseConfirmVmProvider(purchase.code);
    final state = ref.watch(provider);
    final vm = ref.read(provider.notifier);
    if (state.confirmed || purchase.isConfirmed) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('구매확정 완료'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (state.uncertain)
          OutlinedButton(
            onPressed: state.busy ? null : vm.checkResult,
            child: Text(state.busy ? '확인 중' : '처리 상태 확인'),
          )
        else if (purchase.canConfirm)
          OutlinedButton(
            onPressed: state.busy
                ? null
                : () async {
                    final approved = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('상품을 받으셨나요?'),
                        content: const Text(
                          '상품과 상태를 확인한 뒤 구매확정해주세요. 확정하면 판매자에게 대금이 지급됩니다.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('구매확정'),
                          ),
                        ],
                      ),
                    );
                    if (approved == true && context.mounted) await vm.confirm();
                  },
            child: Text(state.busy ? '확인 중' : '구매확정'),
          ),
      ],
    );
  }
}
