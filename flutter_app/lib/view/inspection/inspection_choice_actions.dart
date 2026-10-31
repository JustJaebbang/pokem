import 'package:pokem_app/view/inspection/return_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/inspection/inspection_result.dart';
import 'package:pokem_app/vm/inspection/inspection_choice_vm.dart';

class InspectionChoiceActions extends ConsumerWidget {
  const InspectionChoiceActions({super.key, required this.item});
  final InspectionResult item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inspectionChoiceVmProvider(item.code));
    final vm = ref.read(inspectionChoiceVmProvider(item.code).notifier);
    final result = state.result ?? item;
    if (result.hasChoice) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              result.choice == '반환'
                  ? '반환을 선택했습니다. 반환 접수 후 배송은 담당자가 진행합니다.'
                  : '대리판매를 선택했습니다. 판매상품 등록은 담당자가 진행합니다.',
            ),
          ),
          if (result.choice == '반환')
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReturnView(inspectCode: result.code),
                ),
              ),
              child: const Text('반환내역 보기'),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
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
        else if (item.canChoose)
          Wrap(
            spacing: 12,
            children: [
              for (final choice in InspectionChoice.values)
                OutlinedButton(
                  onPressed: state.busy
                      ? null
                      : () async {
                          final approved = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                '${choice.label}${choice == InspectionChoice.returnItem ? '을' : '를'} 선택하시겠습니까?',
                              ),
                              content: Text(
                                '${choice == InspectionChoice.returnItem ? '선택하면 반환 건이 접수됩니다.' : '선택하면 담당자가 대리판매 등록을 진행합니다.'}\n선택 후에는 변경할 수 없습니다.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('취소'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('선택하기'),
                                ),
                              ],
                            ),
                          );
                          if (approved == true && context.mounted) {
                            await vm.choose(choice);
                          }
                        },
                  child: Text(choice.label),
                ),
            ],
          ),
        if (state.busy)
          const Padding(padding: EdgeInsets.only(top: 8), child: Text('처리 중')),
      ],
    );
  }
}
