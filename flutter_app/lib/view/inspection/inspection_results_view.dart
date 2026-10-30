import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/vm/inspection/inspection_results_vm.dart';
import 'package:pokem_app/view/inspection/inspection_choice_actions.dart';

class InspectionResultsView extends ConsumerWidget {
  const InspectionResultsView({super.key, required this.number});
  final String number;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = inspectionResultsVmProvider(number);
    final result = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('검수 결과'),
        actions: [
          IconButton(
            onPressed: result.isLoading
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e is InspectionException ? e.message : '검수 결과를 불러오지 못했습니다.'),
              TextButton(
                onPressed: () => ref.read(provider.notifier).refresh(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.read(provider.notifier).refresh();
            try {
              await ref.read(provider.future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              SelectableText('신청번호 $number'),
              const SizedBox(height: 20),
              if (items.isEmpty)
                const Text('아직 등록된 검수 카드가 없습니다. 카드가 접수되면 담당자가 등록합니다.'),
              for (final item in items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.status,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('카드 코드 ${item.serialCode}'),
                        const SizedBox(height: 8),
                        SelectableText('검수번호 ${item.code}'),
                        if (item.status == '검수완료') ...[
                          const Divider(height: 32),
                          Text(
                            '등급 · ${item.grade ?? '확인 불가'}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                        ],
                        InspectionChoiceActions(item: item),
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
