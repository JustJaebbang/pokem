import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/manager/manager_dashboard.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/manager/manager_dashboard_vm.dart';

class ManagerDashboardView extends ConsumerWidget {
  const ManagerDashboardView({super.key});

  static const _titles = [
    '통합 대시보드',
    '검수신청 접수',
    '검수 작업',
    '대리판매 등록',
    '품의 신청',
    '발주 / 수주',
  ];

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('POKEM  /  매니저'),
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
              if (constraints.maxWidth >= 720) _navigationRail(state, vm),
              Expanded(child: _content(context, ref, state)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 720
          ? NavigationBar(
              selectedIndex: state.section.index,
              onDestinationSelected: (index) =>
                  vm.selectSection(ManagerSection.values[index]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: '통합',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inbox_outlined),
                  label: '신청',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  label: '검수',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  label: '대리판매',
                ),
                NavigationDestination(
                  icon: Icon(Icons.description_outlined),
                  label: '품의',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  label: '발주',
                ),
              ],
            )
          : null,
    );
  }

  Widget _navigationRail(ManagerDashboardState state, ManagerDashboardVm vm) =>
      NavigationRail(
        selectedIndex: state.section.index,
        labelType: NavigationRailLabelType.all,
        onDestinationSelected: (index) =>
            vm.selectSection(ManagerSection.values[index]),
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: Text('통합'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.inbox_outlined),
            label: Text('검수신청'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.fact_check_outlined),
            label: Text('검수 작업'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.storefront_outlined),
            label: Text('대리판매'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.description_outlined),
            label: Text('품의'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: Text('발주/수주'),
          ),
        ],
      );

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboardState state,
  ) {
    final vm = ref.read(managerDashboardVmProvider.notifier);
    final data = state.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titles[state.section.index],
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(_subtitle(state.section)),
                  ],
                ),
              ),
              if (data != null && state.section == ManagerSection.requests)
                FilledButton.icon(
                  onPressed: state.submitting || data.unassignedRequests == 0
                      ? null
                      : () => _requestDialog(context, ref, data),
                  icon: const Icon(Icons.how_to_reg),
                  label: const Text('검수신청 작성'),
                ),
              if (data != null && state.section == ManagerSection.inspections)
                FilledButton.icon(
                  onPressed:
                      state.submitting || _inspectableRequests(data).isEmpty
                      ? null
                      : () => _inspectionDialog(context, ref, data),
                  icon: const Icon(Icons.add_task),
                  label: const Text('검수 작성'),
                ),
              if (data != null && state.section == ManagerSection.consignments)
                FilledButton.icon(
                  onPressed:
                      state.submitting || data.consignmentCandidates.isEmpty
                      ? null
                      : () => _consignmentCreateDialog(context, ref, data),
                  icon: const Icon(Icons.add_business),
                  label: const Text('대리판매 작성'),
                ),
              if (data != null && state.section == ManagerSection.proposals)
                FilledButton.icon(
                  onPressed: state.submitting
                      ? null
                      : () => _proposalDialog(context, ref, data),
                  icon: const Icon(Icons.add),
                  label: const Text('품의 신청'),
                ),
              if (data != null && state.section == ManagerSection.procurement)
                FilledButton.icon(
                  onPressed: state.submitting
                      ? null
                      : () => _orderDialog(context, ref, data),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('발주 등록'),
                ),
            ],
          ),
        ),
        if (state.loading || state.submitting) const LinearProgressIndicator(),
        if (state.error != null)
          MaterialBanner(
            content: Text(state.error!),
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
                state.loading ? '업무 데이터를 불러오고 있습니다.' : '데이터를 불러오지 못했습니다.',
              ),
            ),
          )
        else if (state.section == ManagerSection.dashboard)
          Expanded(child: _dashboard(context, ref, data))
        else
          Expanded(child: _workspace(context, ref, state)),
      ],
    );
  }

  String _subtitle(ManagerSection section) => switch (section) {
    ManagerSection.dashboard => '검수부터 발주·수주까지 오늘의 업무를 확인하세요.',
    ManagerSection.requests => '접수된 검수신청을 승인하고 실물 카드를 등록합니다.',
    ManagerSection.inspections => '검수를 시작하고 등급과 판정 사유를 기록합니다.',
    ManagerSection.consignments => '대리판매를 선택한 검수 완료 상품을 판매 등록합니다.',
    ManagerSection.proposals => '케이스 발주를 위한 품의를 작성하고 결재 상태를 확인합니다.',
    ManagerSection.procurement => '승인된 품의로 발주하고 수주·입고 수량을 기록합니다.',
  };

  Widget _dashboard(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboard data,
  ) {
    final vm = ref.read(managerDashboardVmProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Metric(
              label: '신규 검수신청',
              value: data.unassignedRequests,
              icon: Icons.mark_email_unread_outlined,
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
              label: '대리판매 대기',
              value: data.consignmentCandidates.length,
              icon: Icons.storefront_outlined,
            ),
            _Metric(
              label: '품의 결재 대기',
              value: data.pendingProposals,
              icon: Icons.approval_outlined,
            ),
            _Metric(
              label: '발주 / 수주',
              value: data.orders.length,
              secondary: data.receives.length,
              icon: Icons.inventory_2_outlined,
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text('업무 바로가기', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width >= 1100 ? 3 : 2,
          childAspectRatio: 2.3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _WorkflowCard(
              title: '검수신청 접수',
              detail: '미배정 ${data.unassignedRequests}건',
              icon: Icons.inbox_outlined,
              onTap: () => vm.selectSection(ManagerSection.requests),
            ),
            _WorkflowCard(
              title: '검수 작업',
              detail: '진행 중 ${data.countStatus('검수중')}건',
              icon: Icons.fact_check_outlined,
              onTap: () => vm.selectSection(ManagerSection.inspections),
            ),
            _WorkflowCard(
              title: '대리판매 등록',
              detail: '등록 대기 ${data.consignmentCandidates.length}건',
              icon: Icons.storefront_outlined,
              onTap: () => vm.selectSection(ManagerSection.consignments),
            ),
            _WorkflowCard(
              title: '품의 신청',
              detail: '전체 ${data.proposals.length}건',
              icon: Icons.description_outlined,
              onTap: () => vm.selectSection(ManagerSection.proposals),
            ),
            _WorkflowCard(
              title: '발주 / 수주',
              detail: '발주 ${data.orders.length}건 · 수주 ${data.receives.length}건',
              icon: Icons.local_shipping_outlined,
              onTap: () => vm.selectSection(ManagerSection.procurement),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text('재고 기준정보', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: data.cases.isEmpty
                ? [const ListTile(title: Text('등록된 케이스가 없습니다.'))]
                : data.cases
                      .map(
                        (item) => ListTile(
                          leading: const Icon(Icons.inventory_outlined),
                          title: Text(item.code),
                          subtitle: Text('일련번호 ${item.serialNo ?? '-'}'),
                          trailing: Text('재고 ${item.stock}개'),
                        ),
                      )
                      .toList(),
          ),
        ),
      ],
    );
  }

  Widget _workspace(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboardState state,
  ) {
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        children: [
          TextField(
            key: ValueKey(state.section),
            onChanged: ref.read(managerDashboardVmProvider.notifier).search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '번호, 코드, 사용자, 업체명 검색',
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
                        onSelected: (_) => ref
                            .read(managerDashboardVmProvider.notifier)
                            .filter(status),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _list(context, ref, state, false),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 4,
                        child: Card(child: _detail(context, ref, state)),
                      ),
                    ],
                  )
                : _list(context, ref, state, true),
          ),
        ],
      ),
    );
  }

  List<_RowData> _rows(ManagerDashboardState state) {
    final data = state.data!;
    final rows = <_RowData>[];
    switch (state.section) {
      case ManagerSection.requests:
        for (final item in data.requests) {
          final registered = data.inspections
              .where((i) => i.requestNumber == item.number)
              .length;
          rows.add(
            _RowData(
              item.number,
              item.number,
              '${item.userId} · ${item.date ?? '-'}',
              item.managerId == null
                  ? '접수 대기'
                  : '$registered / ${item.amount}개',
            ),
          );
        }
      case ManagerSection.inspections:
        for (final item in data.inspections) {
          if (state.status == null || state.status == item.status) {
            rows.add(
              _RowData(
                item.code,
                item.code,
                '${item.userId} · ${item.requestNumber}',
                item.status,
              ),
            );
          }
        }
      case ManagerSection.consignments:
        for (final item in data.consignmentCandidates) {
          rows.add(
            _RowData(
              'candidate:${item.code}',
              item.code,
              '${item.userId} · 등급 ${item.grade ?? '-'}',
              '등록 대기',
            ),
          );
        }
        for (final item in data.consignments) {
          rows.add(
            _RowData(
              'consign:${item.code}',
              item.productCode,
              '${item.userId} · ${item.code}',
              item.completedAt == null ? '판매 중' : '거래 완료',
            ),
          );
        }
      case ManagerSection.proposals:
        for (final item in data.proposals) {
          rows.add(
            _RowData(
              item.number,
              item.name ?? item.number,
              '${item.caseCode} · ${item.date ?? '-'}',
              item.status ?? '-',
            ),
          );
        }
      case ManagerSection.procurement:
        for (final item in data.orders) {
          rows.add(
            _RowData(
              'order:${item.number}',
              item.number,
              '${item.companyCode} · ${item.caseCode}',
              '발주 ${item.amount ?? 0}개',
            ),
          );
        }
        for (final item in data.receives) {
          rows.add(
            _RowData(
              'receive:${item.number}',
              item.number,
              '${item.companyCode} · ${item.orderNumber}',
              '수주/입고 ${item.amount ?? 0}개',
            ),
          );
        }
      case ManagerSection.dashboard:
        break;
    }
    final query = state.query.trim().toLowerCase();
    return rows
        .where(
          (row) => '${row.title} ${row.subtitle} ${row.status}'
              .toLowerCase()
              .contains(query),
        )
        .toList();
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboardState state,
    bool openSheet,
  ) {
    final rows = _rows(state);
    if (rows.isEmpty) return const Center(child: Text('표시할 내역이 없습니다.'));
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = rows[index];
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
                  builder: (_) => FractionallySizedBox(
                    heightFactor: .9,
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
    final vm = ref.read(managerDashboardVmProvider.notifier);
    final enabled = !state.loading && !state.submitting;
    final children = <Widget>[];
    switch (state.section) {
      case ManagerSection.requests:
        final item = data.requests
            .where((value) => value.number == state.selectedId)
            .firstOrNull;
        if (item == null) break;
        final inspections = data.inspections
            .where((value) => value.requestNumber == item.number)
            .toList();
        children.addAll([
          _heading(context, '검수신청 상세'),
          _info('신청번호', item.number),
          _info('신청자', item.userId),
          _info('접수일', item.date ?? '-'),
          _info('담당자', item.managerId ?? '미배정'),
          _info('실물 등록', '${inspections.length} / ${item.amount}개'),
          const SizedBox(height: 14),
        ]);
        if (item.managerId == null) {
          children.add(
            FilledButton.icon(
              onPressed: enabled
                  ? () => vm.approveInspectionRequest(item.number)
                  : null,
              icon: const Icon(Icons.how_to_reg),
              label: const Text('신청 승인·담당 배정'),
            ),
          );
        }
        if (item.managerId != null && inspections.length < item.amount) {
          children.add(
            FilledButton.tonalIcon(
              onPressed: enabled
                  ? () => _simpleDialog(
                      context,
                      ref,
                      title: '검수 상품 등록',
                      fields: const [_DialogField('serial', '카탈로그 일련코드')],
                      submit: (values) =>
                          vm.createInspection(item.number, values['serial']!),
                    )
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('실물 검수 상품 등록'),
            ),
          );
        }
        children.addAll([
          const SizedBox(height: 18),
          for (final inspection in inspections)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(inspection.code),
              subtitle: Text(inspection.status),
            ),
        ]);
      case ManagerSection.inspections:
        final item = data.inspections
            .where((value) => value.code == state.selectedId)
            .firstOrNull;
        if (item == null) break;
        children.addAll([
          _heading(context, '검수 작업 상세'),
          _info('검수코드', item.code),
          _info('카탈로그', item.serialCode),
          _info('신청자', item.userId),
          _info('상태', item.status),
          _info('등급', item.grade ?? '-'),
          _info('판정 사유', item.reason ?? '-'),
          const SizedBox(height: 16),
        ]);
        if (item.status == '검수대기') {
          children.add(
            FilledButton.icon(
              onPressed: enabled ? () => vm.startInspection(item.code) : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('검수 시작'),
            ),
          );
        }
        if (item.status == '검수중') {
          children.add(
            FilledButton.icon(
              onPressed: enabled
                  ? () => _simpleDialog(
                      context,
                      ref,
                      title: '검수 결과',
                      fields: const [
                        _DialogField('grade', '등급'),
                        _DialogField('reason', '판정 사유', maxLines: 3),
                      ],
                      submit: (values) => vm.completeInspection(
                        item.code,
                        values['grade']!,
                        values['reason']!,
                      ),
                    )
                  : null,
              icon: const Icon(Icons.task_alt),
              label: const Text('검수 완료'),
            ),
          );
        }
      case ManagerSection.consignments:
        if (state.selectedId!.startsWith('candidate:')) {
          final item = data.consignmentCandidates
              .where((value) => value.code == state.selectedId!.substring(10))
              .firstOrNull;
          if (item == null) break;
          children.addAll([
            _heading(context, '대리판매 등록 대기'),
            _info('검수코드', item.code),
            _info('소유자', item.userId),
            _info('검수 등급', item.grade ?? '-'),
            _info('판정 사유', item.reason ?? '-'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: enabled
                  ? () => _consignmentDialog(context, ref, data, item)
                  : null,
              icon: const Icon(Icons.add_business),
              label: const Text('판매 상품 등록'),
            ),
          ]);
        } else {
          final item = data.consignments
              .where(
                (value) =>
                    value.code ==
                    state.selectedId!.replaceFirst('consign:', ''),
              )
              .firstOrNull;
          if (item == null) break;
          children.addAll([
            _heading(context, '대리판매 상세'),
            _info('등록코드', item.code),
            _info('상품코드', item.productCode),
            _info('검수코드', item.inspectionCode),
            _info('소유자', item.userId),
            _info('반환 배송업체', item.returnCompanyCode ?? '-'),
            _info('만료일', item.expiresAt ?? '-'),
            _info('거래 완료일', item.completedAt ?? '미완료'),
          ]);
        }
      case ManagerSection.proposals:
        final item = data.proposals
            .where((value) => value.number == state.selectedId)
            .firstOrNull;
        if (item == null) break;
        children.addAll([
          _heading(context, '품의 상세'),
          _info('품의번호', item.number),
          _info('품의명', item.name ?? '-'),
          _info('내용', item.contents ?? '-'),
          _info('케이스', item.caseCode),
          _info('상태', item.status ?? '-'),
          _info('작성자', item.managerId ?? '-'),
          _info('결재자', item.directorId ?? '-'),
        ]);
      case ManagerSection.procurement:
        if (state.selectedId!.startsWith('order:')) {
          final item = data.orders
              .where((value) => value.number == state.selectedId!.substring(6))
              .firstOrNull;
          if (item == null) break;
          final received = data.receives
              .where((value) => value.orderNumber == item.number)
              .fold<int>(0, (sum, value) => sum + (value.amount ?? 0));
          children.addAll([
            _heading(context, '발주 상세'),
            _info('발주번호', item.number),
            _info('품의번호', item.proposalNumber),
            _info('케이스', item.caseCode),
            _info('제조업체', item.companyCode),
            _info('발주수량', '${item.amount ?? 0}개'),
            _info('수주/입고', '$received개'),
            _info('총 발주금액', '${item.price ?? 0}원'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: enabled && received < (item.amount ?? 0)
                  ? () => _receiveDialog(context, ref, item)
                  : null,
              icon: const Icon(Icons.move_to_inbox),
              label: const Text('수주·입고 등록'),
            ),
          ]);
        } else {
          final item = data.receives
              .where(
                (value) =>
                    value.number ==
                    state.selectedId!.replaceFirst('receive:', ''),
              )
              .firstOrNull;
          if (item == null) break;
          children.addAll([
            _heading(context, '수주·입고 상세'),
            _info('수주번호', item.number),
            _info('발주번호', item.orderNumber),
            _info('제조업체', item.companyCode),
            _info('수량', '${item.amount ?? 0}개'),
            _info('금액', '${item.price ?? 0}원'),
            _info('입고일', item.date ?? '-'),
          ]);
        }
      case ManagerSection.dashboard:
        break;
    }
    if (children.isEmpty) return const Center(child: Text('상세 내역을 찾을 수 없습니다.'));
    return ListView(
      key: const Key('managerDetail'),
      padding: const EdgeInsets.all(24),
      children: children,
    );
  }

  List<InspectionRequest> _inspectableRequests(ManagerDashboard data) => data
      .requests
      .where(
        (request) =>
            request.managerId != null &&
            data.inspections
                    .where((item) => item.requestNumber == request.number)
                    .length <
                request.amount,
      )
      .toList();

  Future<void> _requestDialog(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboard data,
  ) => _simpleDialog(
    context,
    ref,
    title: '검수신청 접수',
    fields: [
      _DialogField(
        'request',
        '미배정 검수신청',
        options: {
          for (final item in data.requests.where(
            (item) => item.managerId == null,
          ))
            item.number: '${item.number} · ${item.userId} · ${item.amount}개',
        },
      ),
    ],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .approveInspectionRequest(values['request']!),
  );

  Future<void> _inspectionDialog(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboard data,
  ) => _simpleDialog(
    context,
    ref,
    title: '검수 작성',
    fields: [
      _DialogField(
        'request',
        '검수신청',
        options: {
          for (final item in _inspectableRequests(data))
            item.number: '${item.number} · ${item.userId}',
        },
      ),
      const _DialogField('serial', '카탈로그 일련코드'),
      const _DialogField('grade', '검수 등급'),
      const _DialogField('reason', '검수 등급 판정 사유', maxLines: 3),
    ],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .createInspectionResult(
          values['request']!,
          values['serial']!,
          values['grade']!,
          values['reason']!,
        ),
  );

  Future<void> _consignmentCreateDialog(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboard data,
  ) => _simpleDialog(
    context,
    ref,
    title: '대리판매 작성',
    fields: [
      _DialogField(
        'inspection',
        '검수 완료 상품',
        options: {
          for (final item in data.consignmentCandidates)
            item.code: '${item.code} · ${item.userId} · ${item.grade ?? '-'}',
        },
      ),
      const _DialogField('title', '상품명'),
      const _DialogField('image', '상품 이미지 URL'),
      const _DialogField('contents', '상품 설명', maxLines: 4),
      const _DialogField('price', '판매가', numeric: true),
      _DialogField(
        'company',
        '반환 배송업체',
        options: {
          for (final company in data.deliveryCompanies)
            company.code: company.name ?? company.code,
        },
      ),
    ],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .createConsignment(
          inspectionCode: values['inspection']!,
          title: values['title']!,
          image: values['image']!,
          contents: values['contents']!,
          price: values['price']!,
          returnCompanyCode: values['company']!,
        ),
  );

  Future<void> _proposalDialog(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboard data,
  ) => _simpleDialog(
    context,
    ref,
    title: '품의 신청',
    fields: [
      _DialogField('name', '품의명'),
      const _DialogField('contents', '품의 내용', maxLines: 4),
      _DialogField(
        'case',
        '케이스',
        options: {
          for (final item in data.cases)
            item.code: '${item.code} (재고 ${item.stock})',
        },
      ),
    ],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .createProposal(
          name: values['name']!,
          contents: values['contents']!,
          caseCode: values['case']!,
        ),
  );

  Future<void> _consignmentDialog(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboard data,
    InspectionItem item,
  ) => _simpleDialog(
    context,
    ref,
    title: '대리판매 등록',
    fields: [
      _DialogField('title', '상품명'),
      const _DialogField('image', '상품 이미지 URL'),
      const _DialogField('contents', '상품 설명', maxLines: 4),
      const _DialogField('price', '판매가', numeric: true),
      _DialogField(
        'company',
        '반환 배송업체',
        options: {
          for (final company in data.deliveryCompanies)
            company.code: company.name ?? company.code,
        },
      ),
    ],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .createConsignment(
          inspectionCode: item.code,
          title: values['title']!,
          image: values['image']!,
          contents: values['contents']!,
          price: values['price']!,
          returnCompanyCode: values['company']!,
        ),
  );

  Future<void> _orderDialog(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboard data,
  ) => _simpleDialog(
    context,
    ref,
    title: '발주 등록',
    fields: [
      _DialogField(
        'proposal',
        '승인된 품의',
        options: {
          for (final item in data.proposals.where(
            (item) => item.status == '승인',
          ))
            item.number: item.name ?? item.number,
        },
      ),
      _DialogField(
        'company',
        '제조업체',
        options: {
          for (final item in data.productCompanies)
            item.code: item.name ?? item.code,
        },
      ),
      const _DialogField('price', '총 발주금액', numeric: true),
      const _DialogField('amount', '발주수량', numeric: true),
    ],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .createOrder(
          proposalNumber: values['proposal']!,
          price: values['price']!,
          amount: values['amount']!,
          companyCode: values['company']!,
        ),
  );

  Future<void> _receiveDialog(
    BuildContext context,
    WidgetRef ref,
    OrderRecord order,
  ) => _simpleDialog(
    context,
    ref,
    title: '수주·입고 등록',
    fields: const [
      _DialogField('price', '이번 입고 금액', numeric: true),
      _DialogField('amount', '입고 수량', numeric: true),
    ],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .createReceive(
          orderNumber: order.number,
          price: values['price']!,
          amount: values['amount']!,
        ),
  );

  Future<void> _simpleDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<_DialogField> fields,
    required Future<bool> Function(Map<String, String>) submit,
  }) async {
    final formKey = GlobalKey<FormState>();
    final controllers = {
      for (final field in fields) field.key: TextEditingController(),
    };
    final selected = {
      for (final field in fields.where(
        (field) => field.options != null && field.options!.isNotEmpty,
      ))
        field.key: field.options!.keys.first,
    };
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(managerDashboardVmProvider);
          return PopScope(
            canPop: !state.submitting,
            child: AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final field in fields)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: field.options != null
                                ? DropdownButtonFormField<String>(
                                    initialValue: selected[field.key],
                                    decoration: InputDecoration(
                                      labelText: field.label,
                                    ),
                                    items: field.options!.entries
                                        .map(
                                          (entry) => DropdownMenuItem(
                                            value: entry.key,
                                            child: Text(entry.value),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: state.submitting
                                        ? null
                                        : (value) =>
                                              selected[field.key] = value!,
                                    validator: (value) => value == null
                                        ? '${field.label}을 선택해주세요.'
                                        : null,
                                  )
                                : TextFormField(
                                    controller: controllers[field.key],
                                    enabled: !state.submitting,
                                    maxLines: field.maxLines,
                                    keyboardType: field.numeric
                                        ? TextInputType.number
                                        : TextInputType.text,
                                    decoration: InputDecoration(
                                      labelText: field.label,
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? '${field.label}을 입력해주세요.'
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
                  onPressed: state.submitting
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: state.submitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final values = {
                            for (final field in fields)
                              field.key: field.options == null
                                  ? controllers[field.key]!.text
                                  : selected[field.key]!,
                          };
                          if (await submit(values) && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: Text(state.submitting ? '처리 중…' : '저장'),
                ),
              ],
            ),
          );
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
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

class _RowData {
  const _RowData(this.id, this.title, this.subtitle, this.status);
  final String id, title, subtitle, status;
}

class _DialogField {
  const _DialogField(
    this.key,
    this.label, {
    this.maxLines = 1,
    this.numeric = false,
    this.options,
  });
  final String key, label;
  final int maxLines;
  final bool numeric;
  final Map<String, String>? options;
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    this.secondary,
  });
  final String label;
  final int value;
  final int? secondary;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 170,
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
            const SizedBox(width: 7),
            Expanded(child: Text(label)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          secondary == null ? '$value' : '$value / $secondary',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({
    required this.title,
    required this.detail,
    required this.icon,
    required this.onTap,
  });
  final String title, detail;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
