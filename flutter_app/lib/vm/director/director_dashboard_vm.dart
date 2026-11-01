import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/director/director_dashboard.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

enum DirectorSection {
  dashboard,
  analytics,
  approvals,
  withdrawals,
  managers,
  inventory,
  masterData,
}

class DirectorDashboardState {
  const DirectorDashboardState({
    this.data,
    this.loading = false,
    this.submitting = false,
    this.error,
    this.notice,
    this.section = DirectorSection.dashboard,
    this.query = '',
    this.selectedId,
    this.dateFrom,
    this.dateTo,
    this.managerId,
    this.inspectStatus,
    this.statisticsKind = 'inspections',
    this.statisticsPage,
  });
  final DirectorDashboard? data;
  final bool loading, submitting;
  final String? error, notice, selectedId;
  final String? dateFrom, dateTo, managerId, inspectStatus;
  final String statisticsKind;
  final DirectorStatisticsPage? statisticsPage;
  final DirectorSection section;
  final String query;
  DirectorDashboardState copyWith({
    DirectorDashboard? data,
    bool? loading,
    bool? submitting,
    String? error,
    String? notice,
    DirectorSection? section,
    String? query,
    String? selectedId,
    bool resetSelection = false,
    String? dateFrom,
    String? dateTo,
    String? managerId,
    String? inspectStatus,
    bool clearFilters = false,
    String? statisticsKind,
    DirectorStatisticsPage? statisticsPage,
  }) => DirectorDashboardState(
    data: data ?? this.data,
    loading: loading ?? this.loading,
    submitting: submitting ?? this.submitting,
    error: error,
    notice: notice,
    section: section ?? this.section,
    query: query ?? this.query,
    selectedId: resetSelection ? null : selectedId ?? this.selectedId,
    dateFrom: clearFilters ? null : dateFrom ?? this.dateFrom,
    dateTo: clearFilters ? null : dateTo ?? this.dateTo,
    managerId: clearFilters ? null : managerId ?? this.managerId,
    inspectStatus: clearFilters ? null : inspectStatus ?? this.inspectStatus,
    statisticsKind: statisticsKind ?? this.statisticsKind,
    statisticsPage: statisticsPage ?? this.statisticsPage,
  );
}

class DirectorDashboardVm extends Notifier<DirectorDashboardState> {
  @override
  DirectorDashboardState build() {
    ref.watch(loginVmProvider.select((state) => state.session));
    Future.microtask(refresh);
    return const DirectorDashboardState(loading: true);
  }

  String get _token {
    final session = ref.read(loginVmProvider).session;
    if (session == null ||
        session.isExpired ||
        session.account.role != AccountRole.director) {
      throw const DirectorException('총괄책임자 계정으로 로그인해주세요.', statusCode: 403);
    }
    return session.token;
  }

  Future<void> refresh() async {
    if (state.submitting) return;
    state = state.copyWith(loading: true);
    try {
      final data = await ref
          .read(directorRepositoryProvider)
          .load(
            _token,
            dateFrom: state.dateFrom,
            dateTo: state.dateTo,
            managerId: state.managerId,
            inspectStatus: state.inspectStatus,
          );
      if (ref.mounted) {
        state = state.copyWith(data: data, loading: false);
      }
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(loading: false, error: _message(error));
      }
    }
  }

  void selectSection(DirectorSection section) {
    state = state.copyWith(section: section, query: '', resetSelection: true);
    if (section == DirectorSection.analytics) {
      Future.microtask(() => loadStatistics(state.statisticsKind, offset: 0));
    }
  }

  void search(String query) =>
      state = state.copyWith(query: query, resetSelection: true);
  void select(String id) => state = state.copyWith(selectedId: id);

  Future<void> applyFilters({
    String? dateFrom,
    String? dateTo,
    String? managerId,
    String? inspectStatus,
    bool clear = false,
  }) async {
    state = state.copyWith(
      dateFrom: dateFrom,
      dateTo: dateTo,
      managerId: managerId,
      inspectStatus: inspectStatus,
      clearFilters: clear,
    );
    await refresh();
    if (ref.mounted && state.section == DirectorSection.analytics) {
      await loadStatistics(state.statisticsKind, offset: 0);
    }
  }

  Future<void> loadStatistics(String kind, {int offset = 0}) async {
    state = state.copyWith(loading: true, statisticsKind: kind);
    try {
      final page = await ref
          .read(directorRepositoryProvider)
          .statistics(
            _token,
            kind,
            limit: 20,
            offset: offset,
            dateFrom: state.dateFrom,
            dateTo: state.dateTo,
            managerId: state.managerId,
            inspectStatus: state.inspectStatus,
          );
      if (ref.mounted) {
        state = state.copyWith(loading: false, statisticsPage: page);
      }
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(loading: false, error: _message(error));
      }
    }
  }

  Future<bool> updateSettings({
    required int lowStockThreshold,
    required int deliveryDelayDays,
    required int inspectionUnitPrice,
  }) async => _mutate(
    () => ref
        .read(directorRepositoryProvider)
        .updateSettings(
          _token,
          lowStockThreshold: lowStockThreshold,
          deliveryDelayDays: deliveryDelayDays,
          inspectionUnitPrice: inspectionUnitPrice,
        ),
    '운영 기준값을 저장했습니다.',
  );

  Future<bool> createManager(Map<String, dynamic> values) async => _mutate(
    () => ref.read(directorRepositoryProvider).createManager(_token, values),
    '매니저 계정을 생성했습니다.',
  );

  Future<bool> createReferenceData(
    String path,
    Map<String, dynamic> values,
    String label,
  ) async => _mutate(
    () => ref
        .read(directorRepositoryProvider)
        .createReferenceData(_token, path, values),
    '$label 기준정보를 등록했습니다.',
  );

  Future<bool> updateManager(String id, Map<String, dynamic> values) async =>
      _mutate(
        () => ref
            .read(directorRepositoryProvider)
            .updateManager(_token, id, values),
        '매니저 정보를 변경했습니다.',
      );

  Future<bool> _mutate(Future<Object?> Function() action, String notice) async {
    if (state.submitting) return false;
    state = state.copyWith(submitting: true);
    try {
      await action();
      if (!ref.mounted) return false;
      state = state.copyWith(submitting: false);
      await refresh();
      if (ref.mounted) {
        state = state.copyWith(notice: notice);
      }
      return true;
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(submitting: false, error: _message(error));
      }
      return false;
    }
  }

  Future<void> exportStatistics(String format) async {
    try {
      final result = await ref
          .read(directorRepositoryProvider)
          .exportStatistics(
            _token,
            state.statisticsKind,
            format,
            dateFrom: state.dateFrom,
            dateTo: state.dateTo,
            managerId: state.managerId,
            inspectStatus: state.inspectStatus,
          );
      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}${result.filename}',
      );
      await file.writeAsBytes(result.bytes, flush: true);
      if (ref.mounted) {
        state = state.copyWith(notice: '통계 파일을 저장했습니다: ${file.path}');
      }
    } catch (error) {
      if (ref.mounted) state = state.copyWith(error: _message(error));
    }
  }

  Future<bool> review(String number, String status) async {
    if (state.loading || state.submitting) return false;
    state = state.copyWith(submitting: true);
    try {
      await ref
          .read(directorRepositoryProvider)
          .reviewProposal(_token, number, status);
      if (!ref.mounted) return false;
      state = state.copyWith(submitting: false);
      await refresh();
      if (ref.mounted) {
        state = state.copyWith(notice: '품의를 $status 처리했습니다.');
      }
      return true;
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(submitting: false, error: _message(error));
      }
      return false;
    }
  }

  String _message(Object error) =>
      error is DirectorException ? error.message : '총괄 데이터를 처리하지 못했습니다.';
}

final directorDashboardVmProvider =
    NotifierProvider.autoDispose<DirectorDashboardVm, DirectorDashboardState>(
      DirectorDashboardVm.new,
    );
