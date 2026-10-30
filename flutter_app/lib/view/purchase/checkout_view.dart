import 'package:pokem_app/view/wallet/money_transfer_view.dart';
import 'package:pokem_app/model/wallet/wallet_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/view/products/widgets/product_image.dart';
import 'package:pokem_app/view/purchase/purchase_history_view.dart';
import 'package:pokem_app/vm/purchase/checkout_vm.dart';

class CheckoutView extends ConsumerWidget {
  const CheckoutView({super.key, required this.code});
  final String code;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkoutVmProvider(code));
    final vm = ref.read(checkoutVmProvider(code).notifier);
    final data = state.data;
    return PopScope(
      canPop: !state.paying,
      child: Scaffold(
        appBar: AppBar(title: Text(state.purchase == null ? '결제' : '결제 완료')),
        body: state.loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (state.purchase != null) ...[
                    const Icon(Icons.check_circle_outline, size: 64),
                    const SizedBox(height: 20),
                    Text(
                      '결제가 완료되었습니다.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text('상품을 받은 뒤 구매확정을 진행해주세요.'),
                    const SizedBox(height: 16),
                    SelectableText('구매번호\n${state.purchase!.code}'),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const PurchaseHistoryView(),
                        ),
                      ),
                      child: const Text('구매내역 보기'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('닫기'),
                    ),
                  ] else ...[
                    if (data != null) ...[
                      Text(
                        '주문상품',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            width: 88,
                            height: 100,
                            child: ProductImage(url: data.product.image),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Text(data.product.title)),
                          Text(formatWon(data.product.price)),
                        ],
                      ),
                      const Divider(height: 40),
                      Text(
                        '등록된 주소',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        data.buyer.address.isEmpty
                            ? '등록된 주소가 없습니다.'
                            : data.buyer.address,
                      ),
                      const SizedBox(height: 8),
                      const Text('물품 전달 방법은 판매자와 채팅으로 확인해주세요.'),
                      const Divider(height: 40),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('포켐머니 잔액'),
                        trailing: Text(formatWon(data.buyer.balance)),
                      ),
                      TextButton(
                        onPressed: state.paying || state.uncertain
                            ? null
                            : () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const MoneyTransferView(
                                      action: MoneyAction.recharge,
                                    ),
                                  ),
                                );
                                if (context.mounted) await vm.load();
                              },
                        child: const Text('충전하기'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('결제금액'),
                        trailing: Text(
                          formatWon(data.product.price),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (!data.product.isForSale)
                        const Text('판매중인 상품만 구매할 수 있습니다.'),
                      if (data.buyer.balance < data.product.price)
                        const Text('포켐머니 잔액이 부족합니다.'),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('상품과 결제금액을 확인했습니다.'),
                        value: state.agreed,
                        onChanged: state.paying || state.uncertain
                            ? null
                            : (value) => vm.agree(value ?? false),
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
                    if (state.uncertain) ...[
                      FilledButton(
                        onPressed: state.paying ? null : vm.checkResult,
                        child: Text(state.paying ? '확인 중' : '결제 결과 확인'),
                      ),
                      TextButton(
                        onPressed: state.paying
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PurchaseHistoryView(),
                                ),
                              ),
                        child: const Text('구매내역 보기'),
                      ),
                    ] else if (data == null)
                      OutlinedButton(
                        onPressed: vm.load,
                        child: const Text('다시 불러오기'),
                      )
                    else ...[
                      FilledButton(
                        onPressed: state.canPay ? vm.pay : null,
                        child: Text(
                          state.paying
                              ? '결제 중'
                              : '${formatWon(data.product.price)} 결제하기',
                        ),
                      ),
                      TextButton(
                        onPressed: state.paying ? null : vm.load,
                        child: const Text('금액·잔액 새로고침'),
                      ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}
