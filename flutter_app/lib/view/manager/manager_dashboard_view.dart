import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/manager/manager_dashboard_vm.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class ManagerDashboardView extends ConsumerWidget {
  const ManagerDashboardView({super.key});
  static const _titles = ['검수 신청', '검수 작업', '대리판매'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(managerDashboardVmProvider);
    final vm = ref.read(managerDashboardVmProvider.notifier);
    final auth = ref.watch(loginVmProvider);
    ref.listen(managerDashboardVmProvider, (previous, next) {
      if (next.notice != null && previous?.notice != next.notice) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.notice!)));
      }
    });
    final data = state.data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('POKEM  /  관리자'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: state.loading || state.submitting ? null : vm.refresh,
            icon: const Icon(Icons.refresh),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Text(auth.session?.account.name ?? '')),
          ),
          IconButton(
            tooltip: '로그아웃',
            onPressed: state.submitting || auth.submitting
                ? null
                : () => ref.read(loginVmProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final rail = constraints.maxWidth >= 720;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '운영 대시보드',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text('신청 접수부터 검수 결과까지 한곳에서 확인하세요.'),
                      const SizedBox(height: 18),
                      if (data != null)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _Metric(
                              label: '전체 신청',
                              value: data.requests.length,
                              icon: Icons.inbox_outlined,
                            ),
                            _Metric(
                              label: '검수 대기',
                              value: data.countStatus('검수대기'),
                              icon: Icons.pending_actions,
                            ),
                            _Metric(
                              label: '검수 진행',
                              value: data.countStatus('검수중'),
                              icon: Icons.fact_check_outlined,
                            ),
                            _Metric(
                              label: '검수 완료',
                              value: data.countStatus('검수완료'),
                              icon: Icons.task_alt,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (state.loading || state.submitting)
                  const LinearProgressIndicator(),
                if (state.error != null || auth.error != null)
                  MaterialBanner(
                    content: Text(state.error ?? auth.error!),
                    actions: [
                      TextButton(
                        onPressed: state.loading || state.submitting
                            ? null
                            : vm.refresh,
                        child: const Text('다시 불러오기'),
                      ),
                    ],
                  ),
                if (data == null)
                  Expanded(
                    child: Center(
                      child: Text(
                        state.loading
                            ? '관리자 데이터를 불러오고 있습니다.'
                            : '데이터를 불러오지 못했습니다. 다시 불러오기를 눌러주세요.',
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _titles[state.section.index],
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: ValueKey(state.section),
                            onChanged: vm.search,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: '신청번호, 상품코드 또는 사용자 ID 검색',
                            ),
                          ),
                          if (state.section == ManagerSection.inspections)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Wrap(
                                spacing: 8,
                                children: [null, '검수대기', '검수중', '검수완료']
                                    .map(
                                      (status) => ChoiceChip(
                                        label: Text(status ?? '전체'),
                                        selected: state.status == status,
                                        onSelected: (_) => vm.filter(status),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: wide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: _list(
                                          context,
                                          ref,
                                          state,
                                          false,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 4,
                                        child: Card(
                                          child: _detail(context, ref, state),
                                        ),
                                      ),
                                    ],
                                  )
                                : _list(context, ref, state, true),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
            return Row(
              children: [
                if (rail)
                  NavigationRail(
                    selectedIndex: state.section.index,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (index) =>
                        vm.selectSection(ManagerSection.values[index]),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.inbox_outlined),
                        label: Text('검수 신청'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.fact_check_outlined),
                        label: Text('검수 작업'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.storefront_outlined),
                        label: Text('대리판매'),
                      ),
                    ],
                  ),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 720
          ? NavigationBar(
              selectedIndex: state.section.index,
              onDestinationSelected: (index) =>
                  vm.selectSection(ManagerSection.values[index]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.inbox_outlined),
                  label: '검수 신청',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  label: '검수 작업',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  label: '대리판매',
                ),
              ],
            )
          : null,
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboardState state,
    bool openSheet,
  ) {
    final data = state.data!;
    final rows =
        <({String id, String title, String subtitle, String status})>[];
    switch (state.section) {
      case ManagerSection.requests:
        for (final item in data.requests) {
          final registered = data.inspections
              .where((i) => i.requestNumber == item.number)
              .length;
          rows.add((
            id: item.number,
            title: item.number,
            subtitle: '${item.userId} · ${item.date ?? '접수일 미등록'}',
            status: '$registered / ${item.amount}개 등록',
          ));
        }
      case ManagerSection.inspections:
        for (final item in data.inspections) {
          if (state.status != null && state.status != item.status) continue;
          rows.add((
            id: item.code,
            title: item.code,
            subtitle: '${item.userId} · ${item.requestNumber}',
            status: item.status,
          ));
        }
      case ManagerSection.consignments:
        for (final item in data.consignments) {
          rows.add((
            id: item.code,
            title: item.productCode,
            subtitle: '${item.userId} · ${item.code}',
            status: item.completedAt == null ? '거래 미완료' : '거래 완료',
          ));
        }
    }
    final query = state.query.trim().toLowerCase();
    final filtered = rows
        .where(
          (row) => '${row.title} ${row.subtitle}'.toLowerCase().contains(query),
        )
        .toList();
    if (filtered.isEmpty) return const Center(child: Text('표시할 내역이 없습니다.'));
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = filtered[index];
        return Card(
          color: state.selectedId == row.id
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              row.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${row.subtitle}\n${row.status}'),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ref.read(managerDashboardVmProvider.notifier).select(row.id);
              if (openSheet) {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => FractionallySizedBox(
                    heightFactor: .88,
                    child: Consumer(
                      builder: (context, ref, _) => _detail(
                        context,
                        ref,
                        ref.watch(managerDashboardVmProvider),
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _detail(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboardState state,
  ) {
    final data = state.data;
    if (data == null || state.selectedId == null) {
      return const Center(child: Text('목록에서 항목을 선택해주세요.'));
    }
    final children = <Widget>[];
    final vm = ref.read(managerDashboardVmProvider.notifier);
    final enabled = !state.loading && !state.submitting;
    switch (state.section) {
      case ManagerSection.requests:
        final item = data.requests
            .where((i) => i.number == state.selectedId)
            .firstOrNull;
        if (item == null) return const Center(child: Text('신청을 찾을 수 없습니다.'));
        final inspections = data.inspections
            .where((i) => i.requestNumber == item.number)
            .toList();
        children.addAll([
          _heading(context, '검수 신청 상세'),
          _info('신청번호', item.number),
          _info('신청자', item.userId),
          _info('접수일', item.date ?? '-'),
          _info('담당자', item.managerId ?? '미배정'),
          _info('상품 등록', '${inspections.length} / ${item.amount}개'),
          const SizedBox(height: 16),
          const Text('실물이 도착한 상품의 카탈로그 일련코드를 입력해 등록하세요.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: enabled && inspections.length < item.amount
                ? () => _form(
                    context,
                    ref,
                    title: '검수 상품 등록',
                    labels: const ['카탈로그 일련코드'],
                    limits: const [50],
                    submit: (values) =>
                        vm.createInspection(item.number, values[0]),
                  )
                : null,
            icon: const Icon(Icons.add),
            label: const Text('검수 상품 등록'),
          ),
          const SizedBox(height: 20),
          for (final inspection in inspections)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(inspection.code),
              subtitle: Text(inspection.status),
            ),
        ]);
      case ManagerSection.inspections:
        final item = data.inspections
            .where((i) => i.code == state.selectedId)
            .firstOrNull;
        if (item == null) return const Center(child: Text('검수 상품을 찾을 수 없습니다.'));
        children.addAll([
          _heading(context, '검수 상품 상세'),
          _info('검수코드', item.code),
          _info('카탈로그 코드', item.serialCode),
          _info('신청번호', item.requestNumber),
          _info('신청자', item.userId),
          _info('진행 상태', item.status),
          _info('담당자', item.managerId ?? '미배정'),
          _info('검수 등급', item.grade ?? '-'),
          _info('판정 사유', item.reason ?? '-'),
          _info('사용자 선택', item.choice ?? '-'),
          const SizedBox(height: 20),
          if (item.status == '검수대기')
            FilledButton.icon(
              onPressed: enabled ? () => vm.startInspection(item.code) : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('검수 시작'),
            ),
          if (item.status == '검수중')
            FilledButton.icon(
              onPressed: enabled
                  ? () => _form(
                      context,
                      ref,
                      title: '검수 결과 입력',
                      labels: const ['등급', '판정 사유'],
                      limits: const [20, 200],
                      submit: (values) => vm.completeInspection(
                        item.code,
                        values[0],
                        values[1],
                      ),
                    )
                  : null,
              icon: const Icon(Icons.task_alt),
              label: const Text('검수 완료'),
            ),
        ]);
      case ManagerSection.consignments:
        final item = data.consignments
            .where((i) => i.code == state.selectedId)
            .firstOrNull;
        if (item == null) {
          return const Center(child: Text('대리판매 내역을 찾을 수 없습니다.'));
        }
        children.addAll([
          _heading(context, '대리판매 상세'),
          _info('등록코드', item.code),
          _info('상품코드', item.productCode),
          _info('검수코드', item.inspectionCode),
          _info('소유자', item.userId),
          _info('거래 완료일', item.completedAt ?? '미완료'),
        ]);
    }
    return ListView(
      key: const Key('managerDetail'),
      padding: const EdgeInsets.all(24),
      children: children,
    );
  }

  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        SelectableText(value),
      ],
    ),
  );

  Future<void> _form(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<String> labels,
    required List<int> limits,
    required Future<bool> Function(List<String>) submit,
  }) async {
    final controllers = List.generate(
      labels.length,
      (_) => TextEditingController(),
    );
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(managerDashboardVmProvider);
          return PopScope(
            canPop: !state.submitting && !state.loading,
            child: AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < labels.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextFormField(
                              controller: controllers[i],
                              enabled: !state.submitting && !state.loading,
                              maxLength: limits[i],
                              maxLines: limits[i] > 50 ? 3 : 1,
                              decoration: InputDecoration(labelText: labels[i]),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? '${labels[i]}을 입력해주세요.'
                                  : null,
                            ),
                          ),
                        if (state.error != null)
                          Text(
                            state.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: state.submitting || state.loading
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: state.submitting || state.loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final success = await submit(
                            controllers.map((c) => c.text).toList(),
                          );
                          if (success && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: Text(
                    state.submitting || state.loading ? '처리 중…' : '저장',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    // Dispose after the dialog's closing animation has released its text fields.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final int value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 155,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDDDFD8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '$value',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
