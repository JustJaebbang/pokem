import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/director/director_dashboard.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/director/director_dashboard_vm.dart';

class DirectorDashboardView extends ConsumerWidget {
  const DirectorDashboardView({super.key});
  static const _titles = [
    '총괄 대시보드',
    '상세 운영 통계',
    '품의 결재',
    '회원 탈퇴 현황',
    '매니저 현황',
    '재고 현황',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directorDashboardVmProvider);
    final vm = ref.read(directorDashboardVmProvider.notifier);
    final auth = ref.watch(loginVmProvider);
    ref.listen(directorDashboardVmProvider, (previous, next) {
      if (next.notice != null && previous?.notice != next.notice) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.notice!)));
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('POKEM  /  총괄책임자'),
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
          builder: (context, constraints) => Row(
            children: [
              if (constraints.maxWidth >= 720)
                NavigationRail(
                  selectedIndex: state.section.index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (index) =>
                      vm.selectSection(DirectorSection.values[index]),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      label: Text('총괄'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.analytics_outlined),
                      label: Text('상세 통계'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.approval_outlined),
                      label: Text('품의 결재'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_off_outlined),
                      label: Text('회원 탈퇴'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.groups_outlined),
                      label: Text('매니저'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      label: Text('재고'),
                    ),
                  ],
                ),
              Expanded(child: _content(context, ref, state)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 720
          ? NavigationBar(
              selectedIndex: state.section.index,
              onDestinationSelected: (index) =>
                  vm.selectSection(DirectorSection.values[index]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: '총괄',
                ),
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  label: '통계',
                ),
                NavigationDestination(
                  icon: Icon(Icons.approval_outlined),
                  label: '결재',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_off_outlined),
                  label: '탈퇴',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  label: '매니저',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  label: '재고',
                ),
              ],
            )
          : null,
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    DirectorDashboardState state,
  ) {
    final data = state.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titles[state.section.index],
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(switch (state.section) {
                DirectorSection.dashboard => '조직 전체 운영 현황과 결재 대기 업무를 확인합니다.',
                DirectorSection.analytics => '검수·재고·물류·탈퇴 통계를 그래프와 표로 분석합니다.',
                DirectorSection.approvals => '매니저가 신청한 품의를 검토하고 승인 또는 반려합니다.',
                DirectorSection.withdrawals => '탈퇴 사용자가 선택한 종류와 작성한 사유를 확인합니다.',
                DirectorSection.managers => '등록된 매니저와 담당 부서를 확인합니다.',
                DirectorSection.inventory => '케이스 재고와 가격을 총괄 관점에서 확인합니다.',
              }),
            ],
          ),
        ),
        if (state.loading || state.submitting) const LinearProgressIndicator(),
        if (state.error != null)
          MaterialBanner(
            content: Text(state.error!),
            actions: [
              TextButton(
                onPressed: state.loading
                    ? null
                    : ref.read(directorDashboardVmProvider.notifier).refresh,
                child: const Text('다시 불러오기'),
              ),
            ],
          ),
        if (data == null)
          Expanded(
            child: Center(
              child: Text(
                state.loading ? '총괄 데이터를 불러오고 있습니다.' : '데이터를 불러오지 못했습니다.',
              ),
            ),
          )
        else
          Expanded(
            child: switch (state.section) {
              DirectorSection.dashboard => _dashboard(context, ref, data),
              DirectorSection.analytics => _analytics(context, data.statistics),
              DirectorSection.approvals => _approvals(
                context,
                ref,
                state,
                data,
              ),
              DirectorSection.withdrawals => _withdrawals(
                context,
                ref,
                state,
                data,
              ),
              DirectorSection.managers => _managers(context, ref, state, data),
              DirectorSection.inventory => _inventory(
                context,
                ref,
                state,
                data,
              ),
            },
          ),
      ],
    );
  }

  Widget _dashboard(
    BuildContext context,
    WidgetRef ref,
    DirectorDashboard data,
  ) {
    final m = data.metrics;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Metric(
              '사용자 / 매니저',
              '${m.users} / ${m.managers}',
              Icons.groups_outlined,
            ),
            _Metric(
              '미배정 검수신청',
              '${m.unassignedRequests}',
              Icons.mark_email_unread_outlined,
            ),
            _Metric(
              '검수 진행 / 완료',
              '${m.inspectionsInProgress} / ${m.completedInspections}',
              Icons.fact_check_outlined,
            ),
            _Metric(
              '대리판매 진행',
              '${m.activeConsignments}',
              Icons.storefront_outlined,
            ),
            _Metric('결재 대기', '${m.pendingProposals}', Icons.approval_outlined),
            _Metric('발주', '${m.orders}', Icons.inventory_outlined),
            _Metric(
              '배송 / 반환 진행',
              '${m.deliveriesInProgress} / ${m.returnsInProgress}',
              Icons.local_shipping_outlined,
            ),
            _Metric(
              '결제 / 환급',
              '${m.payments} / ${m.refunds}',
              Icons.payments_outlined,
            ),
            _Metric('케이스 총재고', '${m.caseStock}', Icons.inventory_2_outlined),
            _Metric('탈퇴 사용자', '${m.withdrawnUsers}', Icons.person_off_outlined),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                '운영 위험 요약',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: () => ref
                  .read(directorDashboardVmProvider.notifier)
                  .selectSection(DirectorSection.analytics),
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('상세 통계 보기'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Metric(
              '재고 부족',
              '${data.statistics.lowStockCases.length}',
              Icons.inventory_outlined,
            ),
            _Metric(
              '미입고 발주',
              '${data.statistics.outstandingOrders.length}',
              Icons.move_to_inbox_outlined,
            ),
            _Metric(
              '지연 배송',
              '${data.statistics.delayedDeliveries}',
              Icons.local_shipping_outlined,
            ),
            _Metric(
              '배송 미등록 반환',
              '${data.statistics.returnsWithoutDelivery}',
              Icons.assignment_return_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                '최근 품의',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => ref
                  .read(directorDashboardVmProvider.notifier)
                  .selectSection(DirectorSection.approvals),
              child: const Text('전체 보기'),
            ),
          ],
        ),
        Card(
          child: Column(
            children: data.proposals
                .take(5)
                .map(
                  (item) => ListTile(
                    leading: Icon(
                      item.status == '대기'
                          ? Icons.schedule
                          : item.status == '승인'
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                    ),
                    title: Text(item.name ?? item.number),
                    subtitle: Text(
                      '${item.managerId ?? '-'} · ${item.caseCode}',
                    ),
                    trailing: Text(item.status),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _analytics(BuildContext context, DirectorOperationsStatistics stats) {
    final pipeline = stats.pipeline;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _barChartCard(context, '검수 단계별 현황', [
              ('미배정 신청', pipeline.unassignedRequests),
              ('검수 대기', pipeline.waiting),
              ('검수 진행', pipeline.inProgress),
              ('검수 완료', pipeline.completed),
            ]),
            _barChartCard(
              context,
              '매니저별 검수 완료',
              stats.managerInspections
                  .map(
                    (item) =>
                        (item.managerName ?? item.managerId, item.completed),
                  )
                  .toList(),
            ),
            _barChartCard(
              context,
              '탈퇴 종류 분포',
              stats.quitTypes.map((item) => (item.type, item.count)).toList(),
              emptyText: '탈퇴 기록이 없습니다.',
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionTitle(context, '매니저별 검수 상세', Icons.engineering_outlined),
        _dataTable(
          ['매니저', 'ID', '전체', '완료', '진행', '완료율'],
          stats.managerInspections
              .map(
                (item) => [
                  item.managerName ?? '-',
                  item.managerId,
                  '${item.total}',
                  '${item.completed}',
                  '${item.active}',
                  item.total == 0
                      ? '0%'
                      : '${(item.completed * 100 / item.total).round()}%',
                ],
              )
              .toList(),
          emptyText: '등록된 매니저가 없습니다.',
        ),
        const SizedBox(height: 24),
        _sectionTitle(context, '재고 부족 케이스', Icons.inventory_outlined),
        _dataTable(
          ['케이스', '현재 재고', '부족 기준', '상태'],
          stats.lowStockCases
              .map(
                (item) => [
                  item.caseCode,
                  '${item.stock}개',
                  '${item.threshold}개 이하',
                  item.stock == 0 ? '품절' : '보충 필요',
                ],
              )
              .toList(),
          emptyText: '재고 10개 이하 케이스가 없습니다.',
        ),
        const SizedBox(height: 24),
        _sectionTitle(context, '미입고 발주', Icons.move_to_inbox_outlined),
        _dataTable(
          ['발주번호', '발주일', '케이스', '발주', '입고', '미입고'],
          stats.outstandingOrders
              .map(
                (item) => [
                  item.orderNo,
                  item.orderDate ?? '-',
                  item.caseCode,
                  '${item.orderAmount}',
                  '${item.receivedAmount}',
                  '${item.outstandingAmount}',
                ],
              )
              .toList(),
          emptyText: '미입고 발주가 없습니다.',
        ),
        const SizedBox(height: 24),
        _sectionTitle(
          context,
          '3일 이상 미완료 배송 (${stats.delayedDeliveries}건)',
          Icons.local_shipping_outlined,
        ),
        _dataTable(
          ['배송번호', '등록일', '상태', '담당자', '배송업체'],
          stats.delayedDeliveryItems
              .map(
                (item) => [
                  item.number,
                  item.date ?? '-',
                  item.status ?? '-',
                  item.managerId,
                  item.companyCode,
                ],
              )
              .toList(),
          emptyText: '3일 이상 지연된 배송이 없습니다.',
        ),
        const SizedBox(height: 24),
        _sectionTitle(
          context,
          '배송 미등록 반환 (${stats.returnsWithoutDelivery}건)',
          Icons.assignment_return_outlined,
        ),
        _dataTable(
          ['반환번호', '상태', '사용자', '담당자'],
          stats.returnWithoutDeliveryItems
              .map(
                (item) => [
                  item.number,
                  item.status,
                  item.userId,
                  item.managerId ?? '미배정',
                ],
              )
              .toList(),
          emptyText: '배송 등록이 필요한 반환이 없습니다.',
        ),
      ],
    );
  }

  Widget _barChartCard(
    BuildContext context,
    String title,
    List<(String, int)> items, {
    String emptyText = '표시할 데이터가 없습니다.',
  }) {
    final maxValue = items.fold<int>(0, (max, item) => math.max(max, item.$2));
    return SizedBox(
      width: math.min(440, MediaQuery.sizeOf(context).width - 40),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              if (items.isEmpty)
                Text(emptyText)
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(item.$1)),
                            Text('${item.$2}건'),
                          ],
                        ),
                        const SizedBox(height: 5),
                        LinearProgressIndicator(
                          value: maxValue == 0 ? 0 : item.$2 / maxValue,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(8),
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

  Widget _sectionTitle(BuildContext context, String title, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
      );

  Widget _dataTable(
    List<String> columns,
    List<List<String>> rows, {
    required String emptyText,
  }) => Card(
    child: rows.isEmpty
        ? Padding(padding: const EdgeInsets.all(20), child: Text(emptyText))
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: columns
                  .map((column) => DataColumn(label: Text(column)))
                  .toList(),
              rows: rows
                  .map(
                    (row) => DataRow(
                      cells: row.map((value) => DataCell(Text(value))).toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
  );

  Widget _approvals(
    BuildContext context,
    WidgetRef ref,
    DirectorDashboardState state,
    DirectorDashboard data,
  ) {
    final items = _filterProposals(state, data);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final list = _searchableList(
      context,
      ref,
      state,
      children: items
          .map(
            (item) => Card(
              child: ListTile(
                title: Text(item.name ?? item.number),
                subtitle: Text(
                  '${item.managerId ?? '-'} · ${item.date ?? '-'}',
                ),
                trailing: Text(item.status),
                selected: state.selectedId == item.number,
                onTap: () => _selectOrSheet(
                  context,
                  ref,
                  item.number,
                  wide,
                  () => _proposalDetail(context, ref, state, item),
                ),
              ),
            ),
          )
          .toList(),
    );
    if (!wide) return list;
    final selected = items
        .where((item) => item.number == state.selectedId)
        .firstOrNull;
    return Row(
      children: [
        Expanded(flex: 5, child: list),
        const SizedBox(width: 14),
        Expanded(
          flex: 4,
          child: Card(
            child: selected == null
                ? const Center(child: Text('품의를 선택해주세요.'))
                : _proposalDetail(context, ref, state, selected),
          ),
        ),
      ],
    );
  }

  Widget _proposalDetail(
    BuildContext context,
    WidgetRef ref,
    DirectorDashboardState state,
    DirectorProposal item,
  ) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('품의 상세', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      _info('품의번호', item.number),
      _info('품의명', item.name ?? '-'),
      _info('내용', item.contents ?? '-'),
      _info('작성자', item.managerId ?? '-'),
      _info('케이스', item.caseCode),
      _info('상태', item.status),
      if (item.status == '대기') ...[
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: state.submitting
                    ? null
                    : () => _review(context, ref, item, '반려'),
                icon: const Icon(Icons.close),
                label: const Text('반려'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: state.submitting
                    ? null
                    : () => _review(context, ref, item, '승인'),
                icon: const Icon(Icons.check),
                label: const Text('승인'),
              ),
            ),
          ],
        ),
      ],
    ],
  );

  Widget _managers(
    BuildContext context,
    WidgetRef ref,
    DirectorDashboardState state,
    DirectorDashboard data,
  ) {
    final query = state.query.trim().toLowerCase();
    final items = data.managers.where(
      (item) => '${item.id} ${item.name} ${item.department}'
          .toLowerCase()
          .contains(query),
    );
    return _searchableList(
      context,
      ref,
      state,
      children: items
          .map(
            (item) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text('${item.name} (${item.id})'),
                subtitle: Text('${item.department}\n${item.email ?? '-'}'),
                isThreeLine: true,
                trailing: Text(item.phone ?? '-'),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _withdrawals(
    BuildContext context,
    WidgetRef ref,
    DirectorDashboardState state,
    DirectorDashboard data,
  ) {
    final query = state.query.trim().toLowerCase();
    final items = data.withdrawals.where(
      (item) => '${item.userId} ${item.nickname} ${item.type} ${item.reason}'
          .toLowerCase()
          .contains(query),
    );
    return _searchableList(
      context,
      ref,
      state,
      children: items
          .map(
            (item) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_off_outlined),
                ),
                title: Text('${item.nickname ?? '닉네임 없음'} (${item.userId})'),
                subtitle: Text(
                  '종류: ${item.type}\n사유: ${item.reason?.trim().isNotEmpty == true ? item.reason : '작성하지 않음'}',
                ),
                isThreeLine: true,
                trailing: Text(item.date ?? '-'),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _inventory(
    BuildContext context,
    WidgetRef ref,
    DirectorDashboardState state,
    DirectorDashboard data,
  ) {
    final query = state.query.trim().toLowerCase();
    final items = data.cases.where(
      (item) => '${item.code} ${item.serial}'.toLowerCase().contains(query),
    );
    return _searchableList(
      context,
      ref,
      state,
      children: items
          .map(
            (item) => Card(
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(item.code),
                subtitle: Text(
                  '일련번호 ${item.serial ?? '-'} · 가격 ${item.price ?? 0}원',
                ),
                trailing: Text('재고 ${item.stock}개'),
              ),
            ),
          )
          .toList(),
    );
  }

  List<DirectorProposal> _filterProposals(
    DirectorDashboardState state,
    DirectorDashboard data,
  ) {
    final query = state.query.trim().toLowerCase();
    return data.proposals
        .where(
          (item) =>
              '${item.number} ${item.name} ${item.managerId} ${item.status}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
  }

  Widget _searchableList(
    BuildContext context,
    WidgetRef ref,
    DirectorDashboardState state, {
    required List<Widget> children,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
    child: Column(
      children: [
        TextField(
          key: ValueKey(state.section),
          onChanged: ref.read(directorDashboardVmProvider.notifier).search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: '번호, 이름, 부서, 상태 검색',
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: children.isEmpty
              ? const Center(child: Text('표시할 내역이 없습니다.'))
              : ListView(children: children),
        ),
      ],
    ),
  );

  void _selectOrSheet(
    BuildContext context,
    WidgetRef ref,
    String id,
    bool wide,
    Widget Function() detail,
  ) {
    ref.read(directorDashboardVmProvider.notifier).select(id);
    if (!wide) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: .9,
          child: Consumer(builder: (context, ref, _) => detail()),
        ),
      );
    }
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    DirectorProposal item,
    String status,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('품의 $status'),
            content: Text('${item.name ?? item.number} 품의를 $status 처리할까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(status),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      await ref
          .read(directorDashboardVmProvider.notifier)
          .review(item.number, status);
    }
  }

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 3),
        SelectableText(value),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 180,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 7),
            Expanded(child: Text(label)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
