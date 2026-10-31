import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/formatters/purchase_time.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/model/purchase/purchase_cancellation.dart';
import 'package:pokem_app/vm/purchase/seller_cancel_vm.dart';
import 'package:pokem_app/vm/purchase/seller_cancel_decision_vm.dart';

class SellerCancelView extends ConsumerWidget {
  const SellerCancelView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(sellerCancelVmProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('취소 요청 내역'),
        actions: [
          IconButton(
            onPressed: result.isLoading
                ? null
                : () => ref.read(sellerCancelVmProvider.notifier).refresh(),
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
                Text(e is PurchaseException ? e.message : '취소 요청을 불러오지 못했습니다.'),
                TextButton(
                  onPressed: () =>
                      ref.read(sellerCancelVmProvider.notifier).refresh(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.read(sellerCancelVmProvider.notifier).refresh();
            try {
              await ref.read(sellerCancelVmProvider.future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (items.isEmpty) const Text('받은 취소 요청이 없습니다.'),
              for (final item in items)
                _SellerCancelCard(key: ValueKey(item.code), item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerCancelCard extends ConsumerWidget {
  const _SellerCancelCard({super.key, required this.item});
  final PurchaseCancellation item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerCancelDecisionVmProvider(item.code));
    final vm = ref.read(sellerCancelDecisionVmProvider(item.code).notifier);
    final current = state.result ?? item;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '취소 상태 · ${current.status}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SelectableText('구매번호 ${current.purchaseCode}'),
            const SizedBox(height: 8),
            Text('구매자 ${current.buyerId}'),
            if (current.date != null) ...[
              const SizedBox(height: 8),
              Text('신청 ${formatPurchaseTime(current.date)}'),
            ],
            const SizedBox(height: 16),
            Text('취소 사유\n${current.reason}'),
            if (current.responseReason?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text('처리 사유\n${current.responseReason}'),
            ],
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (state.uncertain && current.status == '요청중')
              OutlinedButton(
                onPressed: state.busy ? null : vm.checkResult,
                child: Text(state.busy ? '확인 중' : '처리 상태 확인'),
              )
            else if (current.status == '요청중' && state.result == null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  for (final decision in CancelDecision.values)
                    OutlinedButton(
                      onPressed: state.busy
                          ? null
                          : () async {
                              final reason = await showDialog<String>(
                                context: context,
                                builder: (_) => _DecisionDialog(
                                  decision: decision,
                                  validateReason: vm.validateReason,
                                ),
                              );
                              if (reason != null && context.mounted) {
                                await vm.decide(decision, reason);
                              }
                            },
                      child: Text(decision.label),
                    ),
                ],
              ),
            ],
            if (state.busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('처리 중'),
              ),
          ],
        ),
      ),
    );
  }
}

class _DecisionDialog extends StatefulWidget {
  const _DecisionDialog({required this.decision, required this.validateReason});
  final CancelDecision decision;
  final String? Function(String?) validateReason;
  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('취소 ${widget.decision.label}'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.decision == CancelDecision.approve
                  ? '물품 전달·반환 여부를 확인해주세요. 승인하면 구매자에게 결제금액이 환불되고 거래가 취소됩니다.'
                  : '취소 요청을 거절하면 거래는 계속 진행됩니다.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reason,
              validator: widget.validateReason,
              maxLength: 255,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '처리 사유 (선택)'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('돌아가기'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _reason.text);
          }
        },
        child: Text(widget.decision.label),
      ),
    ],
  );
}
