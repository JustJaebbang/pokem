import 'package:pokem_app/vm/inspection/inspection_fee_payment_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/vm/inspection/inspection_fee_vm.dart';

class InspectionFeeView extends ConsumerWidget {
  const InspectionFeeView({super.key, required this.number});
  final String number;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = inspectionFeeVmProvider(number);
    final result = ref.watch(provider);
    final payment = ref.watch(inspectionFeePaymentVmProvider(number));
    final vm = ref.read(inspectionFeePaymentVmProvider(number).notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('검수비'),
        actions: [
          IconButton(
            onPressed: result.isLoading || payment.busy
                ? null
                : () => ref.read(provider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e is InspectionException ? e.message : '검수비를 불러오지 못했습니다.'),
                TextButton(
                  onPressed: () => ref.read(provider.notifier).refresh(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        data: (fee) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SelectableText('신청번호 $number'),
            const SizedBox(height: 24),
            if (fee == null)
              const Text('아직 검수비가 등록되지 않았습니다. 담당자가 신청을 확인한 뒤 금액이 등록됩니다.')
            else ...[
              Text(
                payment.completed ? '결제완료' : fee.status,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                fee.price == null ? '금액 확인 불가' : formatWon(fee.price!),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 24),
              SelectableText('결제번호 ${fee.number}'),
              const SizedBox(height: 8),
              Text('등록일 ${fee.date}'),
              if (payment.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    payment.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (!payment.completed && fee.status != '결제완료') ...[
                const SizedBox(height: 24),
                if (payment.uncertain)
                  OutlinedButton(
                    onPressed: payment.busy ? null : vm.checkResult,
                    child: Text(payment.busy ? '확인 중' : '처리 상태 확인'),
                  )
                else if (fee.status == '결제대기' &&
                    fee.price != null &&
                    fee.price! >= 0)
                  FilledButton(
                    onPressed: payment.busy ? null : () => vm.complete(fee),
                    child: Text(
                      payment.busy ? '처리 중' : '${formatWon(fee.price!)} 결제하기',
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
