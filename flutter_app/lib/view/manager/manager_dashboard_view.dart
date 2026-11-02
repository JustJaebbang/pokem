import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/manager/manager_dashboard.dart';
import 'package:pokem_app/model/products/product_photo.dart';
import 'package:pokem_app/view/products/widgets/product_image.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/manager/manager_dashboard_vm.dart';

class ManagerDashboardView extends ConsumerWidget {
  const ManagerDashboardView({super.key});

  static const _titles = [
    '통합 대시보드',
    '판매 중 상품',
    '검수신청 접수',
    '검수 작업',
    '대리판매 등록',
    '품의 신청',
    '발주 / 수주',
    '반환 / 배송',
    '결제 / 정산',
    '기초정보 관리',
    '폐기 관리',
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
          PopupMenuButton<ManagerSection>(
            tooltip: '업무 메뉴',
            onSelected: vm.selectSection,
            itemBuilder: (context) => [
              for (final section in ManagerSection.values)
                PopupMenuItem(
                  value: section,
                  child: Text(_titles[section.index]),
                ),
            ],
            icon: const Icon(Icons.apps),
          ),
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
          ? Builder(
              builder: (context) {
                const itemWidth = 88.0;
                return SingleChildScrollView(
                  key: const Key('managerBottomNavigationScroll'),
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: ManagerSection.values.length * itemWidth,
                    child: NavigationBar(
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      selectedIndex: state.section.index,
                      onDestinationSelected: (index) =>
                          vm.selectSection(ManagerSection.values[index]),
                      destinations: _compactDestinations,
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }

  static const _compactDestinations = [
    NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '통합'),
    NavigationDestination(icon: Icon(Icons.sell_outlined), label: '판매상품'),
    NavigationDestination(icon: Icon(Icons.inbox_outlined), label: '검수신청'),
    NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: '검수작업'),
    NavigationDestination(icon: Icon(Icons.storefront_outlined), label: '대리판매'),
    NavigationDestination(icon: Icon(Icons.description_outlined), label: '품의'),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      label: '발주/수주',
    ),
    NavigationDestination(
      icon: Icon(Icons.local_shipping_outlined),
      label: '반환/배송',
    ),
    NavigationDestination(icon: Icon(Icons.payments_outlined), label: '결제/정산'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), label: '기초정보'),
    NavigationDestination(icon: Icon(Icons.delete_outline), label: '폐기'),
  ];

  Widget _navigationRail(ManagerDashboardState state, ManagerDashboardVm vm) =>
      SizedBox(
        width: 112,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final destinationsHeight = ManagerSection.values.length * 64.0 + 24;
            final railHeight = constraints.maxHeight > destinationsHeight
                ? constraints.maxHeight
                : destinationsHeight;
            return SingleChildScrollView(
              key: const Key('managerNavigationScroll'),
              child: SizedBox(
                height: railHeight,
                child: NavigationRail(
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
                      icon: Icon(Icons.sell_outlined),
                      label: Text('판매상품'),
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
                    NavigationRailDestination(
                      icon: Icon(Icons.local_shipping_outlined),
                      label: Text('반환/배송'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.payments_outlined),
                      label: Text('결제/정산'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      label: Text('기초정보'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.delete_outline),
                      label: Text('폐기'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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
              if (data != null &&
                  state.section == ManagerSection.returnsDelivery)
                FilledButton.icon(
                  onPressed: state.submitting || data.deliveryCompanies.isEmpty
                      ? null
                      : () => _deliveryMenu(context, ref, data),
                  icon: const Icon(Icons.add_road),
                  label: const Text('반환 배송 등록'),
                ),
              if (data != null && state.section == ManagerSection.settlements)
                FilledButton.icon(
                  onPressed: state.submitting || data.pays.isEmpty
                      ? null
                      : () => _receiptDialog(context, ref, data),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('접수증 등록'),
                ),
              if (data != null && state.section == ManagerSection.masterData)
                FilledButton.icon(
                  onPressed: state.submitting
                      ? null
                      : () => _masterMenu(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('기초정보 등록'),
                ),
              if (data != null && state.section == ManagerSection.discards)
                FilledButton.icon(
                  onPressed: state.submitting
                      ? null
                      : () => _discardDialog(context, ref),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('폐기 등록'),
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
    ManagerSection.products => '현재 판매 중인 전체 상품과 등록 정보를 확인합니다.',
    ManagerSection.requests => '접수된 검수신청을 승인하고 실물 카드를 등록합니다.',
    ManagerSection.inspections => '검수를 시작하고 등급과 판정 사유를 기록합니다.',
    ManagerSection.consignments => '대리판매를 선택한 검수 완료 상품을 판매 등록합니다.',
    ManagerSection.proposals => '케이스 발주를 위한 품의를 작성하고 결재 상태를 확인합니다.',
    ManagerSection.procurement => '승인된 품의로 발주하고 수주·입고 수량을 기록합니다.',
    ManagerSection.returnsDelivery => '반환 담당자를 배정하고 배송 등록·상태를 관리합니다.',
    ManagerSection.settlements => '검수비 결제, 접수증과 환급 내역을 관리합니다.',
    ManagerSection.masterData => '케이스와 제조·배송업체 기준정보를 등록합니다.',
    ManagerSection.discards => '판매상품 폐기 이력과 담당자를 관리합니다.',
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
            _Metric(
              label: '미배정 반환',
              value: data.unassignedReturns,
              icon: Icons.assignment_return_outlined,
            ),
            _Metric(
              label: '배송준비',
              value: data.deliveries
                  .where((item) => item.status == '배송준비')
                  .length,
              icon: Icons.local_shipping_outlined,
            ),
            _Metric(
              label: '결제 / 환급',
              value: data.pays.length,
              secondary: data.refunds.length,
              icon: Icons.payments_outlined,
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
            _WorkflowCard(
              title: '반환 / 배송',
              detail:
                  '미배정 반환 ${data.unassignedReturns}건 · 배송 ${data.deliveries.length}건',
              icon: Icons.local_shipping_outlined,
              onTap: () => vm.selectSection(ManagerSection.returnsDelivery),
            ),
            _WorkflowCard(
              title: '결제 / 정산',
              detail: '결제 ${data.pays.length}건 · 환급 ${data.refunds.length}건',
              icon: Icons.payments_outlined,
              onTap: () => vm.selectSection(ManagerSection.settlements),
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
      case ManagerSection.products:
        for (final item in data.products) {
          rows.add(
            _RowData(
              item.code,
              item.title,
              '${item.code} · 등급 ${item.grade}',
              '${item.price}원',
            ),
          );
        }
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
      case ManagerSection.returnsDelivery:
        for (final item in data.returns) {
          rows.add(
            _RowData(
              'return:${item.number}',
              item.number,
              '${item.userId} · ${item.inspectionCode}',
              item.managerId == null ? '담당자 미배정' : item.status,
            ),
          );
        }
        for (final item in data.deliveries) {
          rows.add(
            _RowData(
              'delivery:${item.number}',
              item.number,
              '${item.userId} · ${item.returnNumber ?? item.purchaseCode ?? '-'}',
              item.status,
            ),
          );
        }
      case ManagerSection.settlements:
        for (final item in data.pays) {
          rows.add(
            _RowData(
              'pay:${item.number}',
              item.number,
              '${item.userId} · ${item.requestNumber}',
              item.status,
            ),
          );
        }
        for (final item in data.receipts) {
          rows.add(
            _RowData(
              'receipt:${item.number}',
              item.number,
              '${item.userId} · ${item.payNumber}',
              '접수증',
            ),
          );
        }
        for (final item in data.refunds) {
          rows.add(
            _RowData(
              'refund:${item.number}',
              item.number,
              '${item.userId} · ${item.payNumber}',
              '환급',
            ),
          );
        }
      case ManagerSection.masterData:
        for (final item in data.cases) {
          rows.add(
            _RowData(
              'case:${item.code}',
              item.code,
              item.serialNo ?? '-',
              '재고 ${item.stock}개',
            ),
          );
        }
        for (final item in data.productCompanies) {
          rows.add(
            _RowData(
              'productCompany:${item.code}',
              item.code,
              item.name ?? '-',
              '제조업체',
            ),
          );
        }
        for (final item in data.deliveryCompanies) {
          rows.add(
            _RowData(
              'deliveryCompany:${item.code}',
              item.code,
              item.name ?? '-',
              '배송업체',
            ),
          );
        }
      case ManagerSection.discards:
        for (final item in data.discards) {
          rows.add(
            _RowData(
              'discard:${item.managerId}:${item.productCode}',
              item.productCode,
              item.managerId,
              item.date ?? '-',
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
    const pageSize = 20;
    final pageCount = (rows.length / pageSize).ceil();
    final page = state.page.clamp(0, pageCount - 1);
    final visible = rows.skip(page * pageSize).take(pageSize).toList();
    // 각 탭은 서버에서 받은 최신 100건을 20건씩 나눠 태블릿 렌더링 부담을 줄인다.
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final row = visible[index];
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
                    ref
                        .read(managerDashboardVmProvider.notifier)
                        .select(row.id);
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
          ),
        ),
        if (pageCount > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: '이전 페이지',
                onPressed: page > 0
                    ? () => ref
                          .read(managerDashboardVmProvider.notifier)
                          .changePage(page - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${page + 1} / $pageCount'),
              IconButton(
                tooltip: '다음 페이지',
                onPressed: page + 1 < pageCount
                    ? () => ref
                          .read(managerDashboardVmProvider.notifier)
                          .changePage(page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
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
      case ManagerSection.products:
        final item = data.products
            .where((value) => value.code == state.selectedId)
            .firstOrNull;
        if (item == null) break;
        children.addAll([
          _heading(context, '판매상품 상세'),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 240,
              child: ProductImage(url: item.image, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 16),
          _info('상품코드', item.code),
          _info('카탈로그', item.serialCode),
          _info('상품명', item.title),
          _info('가격', '${item.price}원'),
          _info('등급', item.grade),
          _info('상태', item.status),
          _info('판매자', item.sellerId ?? '-'),
          _info('등록유형', switch (item.saleType) {
            'direct' => '유저판매',
            'consign' => '대리판매',
            _ => '-',
          }),
          _info('설명', item.description),
        ]);
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
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: enabled && data.deliveryCompanies.isNotEmpty
                  ? () => _returnCompanyDialog(context, ref, data, item)
                  : null,
              icon: const Icon(Icons.local_shipping_outlined),
              label: Text(
                item.returnCompanyCode == null ? '반환 배송업체 지정' : '반환 배송업체 변경',
              ),
            ),
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
            _info('잔여수량', '${data.remainingAmount(item)}개'),
            _info('총 발주금액', '${item.price ?? 0}원'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: enabled && received < (item.amount ?? 0)
                  ? () => _receiveDialog(context, ref, item)
                  : null,
              icon: const Icon(Icons.move_to_inbox),
              label: Text(
                data.remainingAmount(item) == 0 ? '입고 완료' : '수주·입고 등록',
              ),
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
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: enabled
                  ? () async {
                      if (await _confirm(
                        context,
                        '입고 취소',
                        '입고 수량만큼 케이스 재고가 함께 차감됩니다. 계속할까요?',
                      )) {
                        await vm.cancelReceive(item.number);
                      }
                    }
                  : null,
              icon: const Icon(Icons.undo),
              label: const Text('오입고 취소'),
            ),
          ]);
        }
      case ManagerSection.returnsDelivery:
        if (state.selectedId!.startsWith('return:')) {
          final item = data.returns
              .where((value) => value.number == state.selectedId!.substring(7))
              .firstOrNull;
          if (item == null) break;
          final delivery = data.deliveries
              .where((value) => value.returnNumber == item.number)
              .firstOrNull;
          children.addAll([
            _heading(context, '반환 상세'),
            _info('반환번호', item.number),
            _info('검수코드', item.inspectionCode),
            _info('사용자', item.userId),
            _info('담당자', item.managerId ?? '미배정'),
            _info('반환 상태', item.status),
            _info('배송', delivery?.number ?? '미등록'),
            const SizedBox(height: 16),
            if (item.managerId == null)
              FilledButton.icon(
                onPressed: enabled ? () => vm.assignReturn(item.number) : null,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('내 담당으로 배정'),
              ),
            if (item.managerId != null && delivery == null)
              FilledButton.icon(
                onPressed: enabled && data.deliveryCompanies.isNotEmpty
                    ? () =>
                          _returnDeliveryForItemDialog(context, ref, data, item)
                    : null,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('반환 배송 등록'),
              ),
          ]);
        } else {
          final item = data.deliveries
              .where(
                (value) =>
                    value.number ==
                    state.selectedId!.replaceFirst('delivery:', ''),
              )
              .firstOrNull;
          if (item == null) break;
          final histories = data.deliveryHistories
              .where((history) => history.deliveryNumber == item.number)
              .toList();
          children.addAll([
            _heading(context, '배송 상세'),
            _info('배송번호', item.number),
            _info('구분', item.returnNumber == null ? '구매 배송' : '반환 배송'),
            _info('원본번호', item.returnNumber ?? item.purchaseCode ?? '-'),
            _info('사용자', item.userId),
            _info('배송업체', item.companyCode ?? '미지정'),
            _info('상태', item.status),
            _info('배송일', item.date ?? '-'),
            const SizedBox(height: 16),
            if (item.status == '배송준비')
              OutlinedButton.icon(
                onPressed: enabled && data.deliveryCompanies.isNotEmpty
                    ? () => _deliveryCompanyDialog(context, ref, data, item)
                    : null,
                icon: const Icon(Icons.local_shipping_outlined),
                label: Text(item.companyCode == null ? '배송업체 지정' : '배송업체 변경'),
              ),
            if (item.status != '배송완료')
              FilledButton.icon(
                onPressed: enabled && item.companyCode != null
                    ? () => _deliveryStatusDialog(context, ref, item)
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: Text(item.status == '배송준비' ? '배송 시작' : '배송 완료'),
              ),
            const SizedBox(height: 24),
            _heading(context, '처리 이력'),
            if (histories.isEmpty)
              const Text('기록된 처리 이력이 없습니다.')
            else
              for (final history in histories)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(
                      history.previousStatus == null
                          ? history.changedStatus
                          : '${history.previousStatus} → ${history.changedStatus}',
                    ),
                    subtitle: Text(
                      '${history.managerId} · ${history.changedAt}'
                      '${history.memo == null ? '' : '\n${history.memo}'}',
                    ),
                  ),
                ),
          ]);
        }
      case ManagerSection.settlements:
        if (state.selectedId!.startsWith('pay:')) {
          final item = data.pays
              .where((value) => value.number == state.selectedId!.substring(4))
              .firstOrNull;
          if (item == null) break;
          final refunded = data.refunds.any(
            (value) => value.payNumber == item.number,
          );
          children.addAll([
            _heading(context, '결제 상세'),
            _info('결제번호', item.number),
            _info('검수신청', item.requestNumber),
            _info('사용자', item.userId),
            _info('금액', '${item.price ?? 0}원'),
            _info('상태', item.status),
            const SizedBox(height: 16),
            if (item.status == '결제대기')
              FilledButton.tonalIcon(
                onPressed: enabled
                    ? () => _payStatusDialog(context, ref, item)
                    : null,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('결제 취소'),
              ),
            if (item.status == '결제대기') const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: enabled && !refunded && item.status == '결제완료'
                  ? () async {
                      if (await _confirm(
                        context,
                        '환급 등록',
                        '이 결제의 환급 내역을 등록할까요?',
                      )) {
                        await vm.createRefund(item.number);
                      }
                    }
                  : null,
              icon: const Icon(Icons.currency_exchange),
              label: Text(refunded ? '환급 완료' : '환급 등록'),
            ),
          ]);
        } else if (state.selectedId!.startsWith('receipt:')) {
          final item = data.receipts
              .where((value) => value.number == state.selectedId!.substring(8))
              .firstOrNull;
          if (item == null) break;
          children.addAll([
            _heading(context, '접수증 상세'),
            _info('접수번호', item.number),
            _info('결제번호', item.payNumber),
            _info('상품코드', item.productCode),
            _info('수량', '${item.amount ?? 0}개'),
            _info('접수일', item.date ?? '-'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: enabled
                  ? () async {
                      if (await _confirm(
                        context,
                        '접수증 취소',
                        '오입력한 접수증을 취소할까요?',
                      )) {
                        await vm.cancelReceipt(item.number);
                      }
                    }
                  : null,
              icon: const Icon(Icons.undo),
              label: const Text('접수증 취소'),
            ),
          ]);
        } else {
          final item = data.refunds
              .where(
                (value) =>
                    value.number ==
                    state.selectedId!.replaceFirst('refund:', ''),
              )
              .firstOrNull;
          if (item == null) break;
          children.addAll([
            _heading(context, '환급 상세'),
            _info('환급번호', item.number),
            _info('결제번호', item.payNumber),
            _info('사용자', item.userId),
            _info('환급액', '${item.price ?? 0}원'),
            _info('환급일', item.date ?? '-'),
          ]);
        }
      case ManagerSection.masterData:
        final id = state.selectedId!;
        if (id.startsWith('case:')) {
          final item = data.cases
              .where((value) => value.code == id.substring(5))
              .firstOrNull;
          if (item != null) {
            children.addAll([
              _heading(context, '케이스 상세'),
              _info('코드', item.code),
              _info('일련번호', item.serialNo ?? '-'),
              _info('가격', '${item.price ?? 0}원'),
              _info('재고', '${item.stock}개'),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: enabled
                    ? () => _caseEditDialog(context, ref, item)
                    : null,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('가격·재고 수정'),
              ),
            ]);
          }
        } else {
          final delivery = id.startsWith('deliveryCompany:');
          final prefix = delivery ? 'deliveryCompany:' : 'productCompany:';
          final items = delivery
              ? data.deliveryCompanies
              : data.productCompanies;
          final item = items
              .where((value) => value.code == id.substring(prefix.length))
              .firstOrNull;
          if (item != null) {
            children.addAll([
              _heading(context, delivery ? '배송업체 상세' : '제조업체 상세'),
              _info('업체코드', item.code),
              _info('업체명', item.name ?? '-'),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: enabled
                    ? () => _companyEditDialog(context, ref, item, delivery)
                    : null,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('업체명 수정'),
              ),
            ]);
          }
        }
      case ManagerSection.discards:
        final id = state.selectedId!.substring(8);
        final separator = id.indexOf(':');
        final manager = id.substring(0, separator);
        final product = id.substring(separator + 1);
        final item = data.discards
            .where(
              (value) =>
                  value.managerId == manager && value.productCode == product,
            )
            .firstOrNull;
        if (item != null) {
          children.addAll([
            _heading(context, '폐기 상세'),
            _info('판매상품', item.productCode),
            _info('담당자', item.managerId),
            _info('폐기일', item.date ?? '-'),
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
    ManagerDashboard data, {
    InspectionItem? selectedItem,
  }) async {
    final formKey = GlobalKey<FormState>();
    final values = <String, String>{
      'inspection': selectedItem?.code ?? data.consignmentCandidates.first.code,
      'title': '',
      'contents': '',
      'price': '',
      'company': data.deliveryCompanies.isEmpty
          ? ''
          : data.deliveryCompanies.first.code,
    };
    ProductPhoto? photo;
    var picking = false;
    String? photoError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Consumer(
          builder: (dialogContext, ref, _) {
            final state = ref.watch(managerDashboardVmProvider);
            return PopScope(
              canPop: !state.submitting && !picking,
              child: AlertDialog(
                title: const Text('대리판매 작성'),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: values['inspection'],
                            decoration: const InputDecoration(
                              labelText: '검수 완료 상품',
                            ),
                            items: data.consignmentCandidates
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item.code,
                                    child: Text(
                                      '${item.code} · ${item.userId} · ${item.grade ?? '-'}',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: state.submitting || selectedItem != null
                                ? null
                                : (value) => values['inspection'] = value!,
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            key: const Key('selectConsignmentPhoto'),
                            onTap: state.submitting || picking
                                ? null
                                : () async {
                                    setDialogState(() {
                                      picking = true;
                                      photoError = null;
                                    });
                                    try {
                                      final selected = await ref
                                          .read(
                                            managerDashboardVmProvider.notifier,
                                          )
                                          .pickConsignmentPhoto();
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        picking = false;
                                        if (selected != null) photo = selected;
                                      });
                                    } catch (_) {
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        picking = false;
                                        photoError = '사진을 불러오지 못했습니다. JPEG·PNG·WebP, 5MB 이하 파일인지 확인해주세요.';
                                      });
                                    }
                                  },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              height: 190,
                              width: double.infinity,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Theme.of(dialogContext)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: photo == null
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 44,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          picking ? '사진을 불러오는 중…' : '상품 사진 선택',
                                        ),
                                      ],
                                    )
                                  : Image.memory(
                                      photo!.bytes,
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          ),
                          if (photo != null)
                            TextButton(
                              onPressed: state.submitting || picking
                                  ? null
                                  : () => setDialogState(() => photo = null),
                              child: const Text('사진 다시 선택'),
                            ),
                          if (photoError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                photoError!,
                                style: TextStyle(
                                  color: Theme.of(dialogContext)
                                      .colorScheme
                                      .error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: values['title'],
                            enabled: !state.submitting,
                            maxLength: 100,
                            decoration: const InputDecoration(labelText: '상품명'),
                            onChanged: (value) => values['title'] = value,
                            validator: (value) => value?.trim().isEmpty == false
                                ? null
                                : '상품명을 입력해주세요.',
                          ),
                          TextFormField(
                            initialValue: values['contents'],
                            enabled: !state.submitting,
                            maxLines: 4,
                            maxLength: 500,
                            decoration: const InputDecoration(
                              labelText: '상품 설명',
                            ),
                            onChanged: (value) => values['contents'] = value,
                            validator: (value) => value?.trim().isEmpty == false
                                ? null
                                : '상품 설명을 입력해주세요.',
                          ),
                          TextFormField(
                            initialValue: values['price'],
                            enabled: !state.submitting,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: '판매가',
                              suffixText: '원',
                            ),
                            onChanged: (value) => values['price'] = value,
                            validator: (value) {
                              final price = int.tryParse(value ?? '');
                              return price != null && price > 0
                                  ? null
                                  : '1원 이상의 판매가를 입력해주세요.';
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: values['company']!.isEmpty
                                ? null
                                : values['company'],
                            decoration: const InputDecoration(
                              labelText: '반환 배송업체',
                            ),
                            items: data.deliveryCompanies
                                .map(
                                  (company) => DropdownMenuItem(
                                    value: company.code,
                                    child: Text(company.name ?? company.code),
                                  ),
                                )
                                .toList(),
                            onChanged: state.submitting
                                ? null
                                : (value) => values['company'] = value!,
                            validator: (value) =>
                                value == null ? '반환 배송업체를 선택해주세요.' : null,
                          ),
                          if (state.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                state.error!,
                                style: TextStyle(
                                  color: Theme.of(dialogContext)
                                      .colorScheme
                                      .error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: state.submitting || picking
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('취소'),
                  ),
                  FilledButton.icon(
                    onPressed: state.submitting || picking
                        ? null
                        : () async {
                            final valid =
                                formKey.currentState?.validate() == true;
                            if (photo == null) {
                              setDialogState(
                                () => photoError = '상품 사진을 선택해주세요.',
                              );
                            }
                            if (!valid || photo == null) return;
                            final success = await ref
                                .read(managerDashboardVmProvider.notifier)
                                .createConsignmentWithPhoto(
                                  inspectionCode: values['inspection']!,
                                  title: values['title']!,
                                  photo: photo!,
                                  contents: values['contents']!,
                                  price: values['price']!,
                                  returnCompanyCode: values['company']!,
                                );
                            if (success && dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(state.submitting ? '업로드 중…' : '사진 업로드 후 등록'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

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
  ) => _consignmentCreateDialog(context, ref, data, selectedItem: item);

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

  Future<void> _returnCompanyDialog(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboard data,
    ConsignmentRecord item,
  ) => _simpleDialog(
    context,
    ref,
    title: '반환 배송업체 지정',
    fields: [_companyField(data)],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .setConsignmentReturnCompany(item.code, values['company']!),
  );

  _DialogField _companyField(ManagerDashboard data) => _DialogField(
    'company',
    '배송업체',
    options: {
      for (final company in data.deliveryCompanies)
        company.code: company.name ?? company.code,
    },
  );

  Future<void> _returnDeliveryDialog(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboard data,
  ) => _simpleDialog(
    context,
    ref,
    title: '반환 배송 등록',
    fields: [
      _DialogField(
        'return',
        '담당 반환 건',
        options: {
          // 이미 배송이 만들어진 반환 건은 중복 등록 후보에서 제외한다.
          for (final item in data.returns.where(
            (item) =>
                item.managerId != null &&
                !data.deliveries.any(
                  (delivery) => delivery.returnNumber == item.number,
                ),
          ))
            item.number: '${item.number} · ${item.userId}',
        },
      ),
      _companyField(data),
    ],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .createReturnDelivery(values['return']!, values['company']!),
  );

  Future<void> _purchaseDeliveryDialog(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboard data,
  ) => _simpleDialog(
    context,
    ref,
    title: '구매 배송 등록',
    fields: [
      _DialogField(
        'purchase',
        '배송 대기 구매 건',
        options: {
          for (final item in data.purchases.where(
            (item) => !data.deliveries.any(
              (delivery) => delivery.purchaseCode == item.code,
            ),
          ))
            item.code: '${item.title ?? item.productCode} · ${item.userId}',
        },
      ),
      _companyField(data),
    ],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .createPurchaseDelivery(values['purchase']!, values['company']!),
  );

  Future<void> _deliveryMenu(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboard data,
  ) async {
    final type = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('배송 구분'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'return'),
            child: const ListTile(
              leading: Icon(Icons.assignment_return_outlined),
              title: Text('반환 배송'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'purchase'),
            child: const ListTile(
              leading: Icon(Icons.shopping_bag_outlined),
              title: Text('구매 배송'),
            ),
          ),
        ],
      ),
    );
    if (type == null || !context.mounted) return;
    if (type == 'return') {
      await _returnDeliveryDialog(context, ref, data);
    } else {
      await _purchaseDeliveryDialog(context, ref, data);
    }
  }

  Future<void> _returnDeliveryForItemDialog(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboard data,
    ReturnRecord item,
  ) => _simpleDialog(
    context,
    ref,
    title: '반환 배송 등록',
    fields: [_companyField(data)],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .createReturnDelivery(item.number, values['company']!),
  );

  Future<void> _payStatusDialog(
    BuildContext context,
    WidgetRef ref,
    PayRecord item,
  ) => _simpleDialog(
    context,
    ref,
    title: '결제 상태 변경',
    fields: const [
      _DialogField('status', '결제 상태', options: {'결제취소': '결제취소'}),
    ],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .updatePayStatus(item.number, values['status']!),
  );

  Future<void> _receiptDialog(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboard data,
  ) => _simpleDialog(
    context,
    ref,
    title: '접수증 등록',
    fields: [
      _DialogField(
        'pay',
        '미접수 결제 건',
        options: {
          for (final item in data.pays.where(
            (pay) => !data.receipts.any(
              (receipt) => receipt.payNumber == pay.number,
            ),
          ))
            item.number: '${item.number} · ${item.userId}',
        },
      ),
      _DialogField(
        'product',
        '판매상품',
        options: {
          for (final item in data.purchases)
            item.productCode: item.title ?? item.productCode,
        },
      ),
      const _DialogField('amount', '접수 수량', numeric: true),
    ],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .createReceipt(
          payNumber: values['pay']!,
          productCode: values['product']!,
          amount: values['amount']!,
        ),
  );

  Future<void> _masterMenu(BuildContext context, WidgetRef ref) async {
    final type = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('등록할 기초정보'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'case'),
            child: const ListTile(
              leading: Icon(Icons.inventory_outlined),
              title: Text('케이스'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'product'),
            child: const ListTile(
              leading: Icon(Icons.factory_outlined),
              title: Text('제조업체'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'delivery'),
            child: const ListTile(
              leading: Icon(Icons.local_shipping_outlined),
              title: Text('배송업체'),
            ),
          ),
        ],
      ),
    );
    if (type == null || !context.mounted) return;
    if (type == 'case') {
      await _simpleDialog(
        context,
        ref,
        title: '케이스 등록',
        fields: const [
          _DialogField('serial', '케이스 일련번호'),
          _DialogField('price', '가격', numeric: true),
          _DialogField('stock', '초기 재고', numeric: true),
        ],
        submit: (values) => ref
            .read(managerDashboardVmProvider.notifier)
            .createCase(
              serial: values['serial']!,
              price: values['price']!,
              stock: values['stock']!,
            ),
      );
    } else {
      await _simpleDialog(
        context,
        ref,
        title: type == 'product' ? '제조업체 등록' : '배송업체 등록',
        fields: const [
          _DialogField('code', '업체 코드'),
          _DialogField('name', '업체명'),
        ],
        submit: (values) => type == 'product'
            ? ref
                  .read(managerDashboardVmProvider.notifier)
                  .createProductCompany(values['code']!, values['name']!)
            : ref
                  .read(managerDashboardVmProvider.notifier)
                  .createDeliveryCompany(values['code']!, values['name']!),
      );
    }
  }

  Future<void> _discardDialog(BuildContext context, WidgetRef ref) =>
      _simpleDialog(
        context,
        ref,
        title: '판매상품 폐기 등록',
        fields: [
          _DialogField(
            'product',
            '폐기 대상 판매상품',
            options: {
              for (final code
                  in {
                    ...ref
                        .read(managerDashboardVmProvider)
                        .data!
                        .purchases
                        .map((item) => item.productCode),
                    ...ref
                        .read(managerDashboardVmProvider)
                        .data!
                        .consignments
                        .map((item) => item.productCode),
                  }.where(
                    (code) => !ref
                        .read(managerDashboardVmProvider)
                        .data!
                        .discards
                        .any((item) => item.productCode == code),
                  ))
                code: code,
            },
          ),
        ],
        submit: (values) async {
          if (!await _confirm(
            context,
            '폐기 등록',
            '${values['product']} 상품을 폐기 처리할까요?',
          )) {
            return false;
          }
          return ref
              .read(managerDashboardVmProvider.notifier)
              .createDiscard(values['product']!);
        },
      );

  Future<void> _caseEditDialog(
    BuildContext context,
    WidgetRef ref,
    CaseRecord item,
  ) => _simpleDialog(
    context,
    ref,
    title: '케이스 가격·재고 수정',
    fields: const [
      _DialogField('price', '가격', numeric: true),
      _DialogField('stock', '재고', numeric: true),
    ],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .updateCase(item.code, values['price']!, values['stock']!),
  );

  Future<void> _companyEditDialog(
    BuildContext context,
    WidgetRef ref,
    CompanyRecord item,
    bool delivery,
  ) => _simpleDialog(
    context,
    ref,
    title: delivery ? '배송업체명 수정' : '제조업체명 수정',
    fields: const [_DialogField('name', '업체명')],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .updateCompany(item.code, values['name']!, delivery: delivery),
  );

  Future<void> _deliveryCompanyDialog(
    BuildContext context,
    WidgetRef ref,
    ManagerDashboard data,
    DeliveryRecord item,
  ) => _simpleDialog(
    context,
    ref,
    title: '배송업체 지정',
    fields: [_companyField(data)],
    submit: (values) => ref
        .read(managerDashboardVmProvider.notifier)
        .assignDeliveryCompany(item.number, values['company']!),
  );

  Future<void> _deliveryStatusDialog(
    BuildContext context,
    WidgetRef ref,
    DeliveryRecord item,
  ) {
    final next = item.status == '배송준비' ? '배송중' : '배송완료';
    return _simpleDialog(
      context,
      ref,
      title: next == '배송중' ? '배송 시작 처리' : '배송 완료 처리',
      fields: const [
        _DialogField(
          'memo',
          '처리 메모 (선택)',
          maxLines: 3,
          maxLength: 500,
          isRequired: false,
        ),
      ],
      submit: (values) async {
        if (next == '배송완료' &&
            !await _confirm(context, '배송 완료 처리', '완료 후 이전 상태로 되돌릴 수 없습니다.')) {
          return false;
        }
        return ref
            .read(managerDashboardVmProvider.notifier)
            .updateDeliveryStatus(item.number, next, memo: values['memo']!);
      },
    );
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String message,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('확인'),
            ),
          ],
        ),
      ) ??
      false;

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
                                    maxLength: field.maxLength,
                                    keyboardType: field.numeric
                                        ? TextInputType.number
                                        : TextInputType.text,
                                    decoration: InputDecoration(
                                      labelText: field.label,
                                    ),
                                    validator: (value) {
                                      if (field.isRequired &&
                                          (value == null ||
                                              value.trim().isEmpty)) {
                                        return '${field.label}을 입력해주세요.';
                                      }
                                      if (field.maxLength != null &&
                                          (value?.trim().length ?? 0) >
                                              field.maxLength!) {
                                        return '${field.maxLength}자까지 입력해주세요.';
                                      }
                                      return null;
                                    },
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
    this.maxLength,
    this.isRequired = true,
  });
  final String key, label;
  final int maxLines;
  final bool numeric;
  final int? maxLength;
  final bool isRequired;
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
