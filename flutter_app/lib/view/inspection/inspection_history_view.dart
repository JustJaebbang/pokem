import 'package:pokem_app/view/inspection/inspection_fee_view.dart';
import 'package:pokem_app/view/inspection/inspection_results_view.dart';
import 'package:pokem_app/vm/inspection/inspection_create_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/core/formatters/purchase_time.dart';
import 'package:pokem_app/vm/inspection/inspection_history_vm.dart';
import 'package:pokem_app/view/inspection/inspection_create_view.dart';

class InspectionHistoryView extends ConsumerWidget {
  const InspectionHistoryView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(inspectionHistoryVmProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('검수신청 내역')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          ref.read(inspectionCreateVmProvider.notifier).newRequest();
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const InspectionCreateView(),
            ),
          );
          if (context.mounted) {
            ref.read(inspectionHistoryVmProvider.notifier).refresh();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('신청하기'),
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e is InspectionException ? e.message : '신청내역을 불러오지 못했습니다.'),
              TextButton(
                onPressed: () =>
                    ref.read(inspectionHistoryVmProvider.notifier).refresh(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (requests) => RefreshIndicator(
          onRefresh: () async {
            ref.read(inspectionHistoryVmProvider.notifier).refresh();
            try {
              await ref.read(inspectionHistoryVmProvider.future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              if (requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('검수신청 내역이 없습니다.'),
                ),
              for (final request in requests)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText('신청번호 ${request.number}'),
                        const SizedBox(height: 12),
                        Text(
                          request.amount == null
                              ? '수량 확인 불가'
                              : '${request.amount}장',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          request.date == null
                              ? '신청일 확인 불가'
                              : '신청일 ${formatPurchaseTime(request.zonedDate)}',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          request.managerId == null ? '담당자 배정 전' : '담당자 배정됨',
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  InspectionResultsView(number: request.number),
                            ),
                          ),
                          child: const Text('검수 결과 보기'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  InspectionFeeView(number: request.number),
                            ),
                          ),
                          child: const Text('검수비 확인'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
