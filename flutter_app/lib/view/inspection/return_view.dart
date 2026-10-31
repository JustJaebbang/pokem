import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/vm/inspection/return_vm.dart';

class ReturnView extends ConsumerWidget {
  const ReturnView({super.key, this.inspectCode});
  final String? inspectCode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = returnVmProvider(inspectCode);
    final result = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('반환내역'),
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e is InspectionException ? e.message : '반환내역을 불러오지 못했습니다.',
                ),
                TextButton(
                  onPressed: () => ref.read(provider.notifier).refresh(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        data: (page) => RefreshIndicator(
          onRefresh: () async {
            ref.read(provider.notifier).refresh();
            try {
              await ref.read(provider.future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              if (inspectCode != null) ...[
                SelectableText('검수번호 $inspectCode'),
                const SizedBox(height: 16),
              ],
              if (page.items.isEmpty) const Text('등록된 반환내역이 없습니다.'),
              for (final item in page.items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.managerId == null ? '담당자 배정 전' : '담당자 배정됨',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        SelectableText('반환번호 ${item.number}'),
                        const SizedBox(height: 8),
                        SelectableText('검수번호 ${item.inspectCode}'),
                      ],
                    ),
                  ),
                ),
              if (page.error != null)
                Text(
                  page.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (page.hasMore)
                OutlinedButton(
                  onPressed: page.loadingMore
                      ? null
                      : () => ref.read(provider.notifier).loadMore(),
                  child: Text(page.loadingMore ? '불러오는 중' : '더 보기'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
