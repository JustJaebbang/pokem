import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/mypage/pending_actions.dart';
import 'package:pokem_app/vm/mypage/pending_actions_vm.dart';
import 'package:pokem_app/view/inspection/inspection_fee_view.dart';
import 'package:pokem_app/view/inspection/inspection_results_view.dart';
import 'package:pokem_app/view/purchase/seller_cancel_view.dart';

class PendingActionsCard extends ConsumerWidget {
  const PendingActionsCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(pendingActionsVmProvider);
    Future<void> open(Widget page) async {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => page));
      if (context.mounted) {
        ref.read(pendingActionsVmProvider.notifier).refresh();
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '지금 처리할 일',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '처리할 일 새로고침',
                  onPressed: result.isLoading
                      ? null
                      : () => ref
                            .read(pendingActionsVmProvider.notifier)
                            .refresh(),
                  icon: const Icon(Icons.refresh, size: 20),
                ),
              ],
            ),
            result.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e is PendingActionsException
                        ? e.message
                        : '처리할 일을 불러오지 못했습니다.',
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(pendingActionsVmProvider.notifier).refresh(),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
              data: (items) => Column(
                children: [
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('지금 처리할 일이 없습니다.'),
                    ),
                  if (items.fees > 0)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('검수비 결제 대기'),
                      trailing: Text('${items.fees}건 ›'),
                      onTap: () =>
                          open(InspectionFeeView(number: items.feeRequest!)),
                    ),
                  if (items.choices > 0)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('반환·대리판매 선택 대기'),
                      trailing: Text('${items.choices}장 ›'),
                      onTap: () => open(
                        InspectionResultsView(number: items.choiceRequest!),
                      ),
                    ),
                  if (items.cancellations > 0)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('취소 요청 확인'),
                      trailing: Text('${items.cancellations}건 ›'),
                      onTap: () => open(const SellerCancelView()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
