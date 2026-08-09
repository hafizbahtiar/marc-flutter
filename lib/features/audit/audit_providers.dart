import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/features/audit/audit_models.dart';

const _pageSize = 50;

/// Penapis jejak audit. Sebahagian daripada kunci provider, jadi menukar
/// penapis akan bina semula notifier dan memuat semula dari mula.
class AuditFilter {
  const AuditFilter({this.entityType, this.action});

  /// null = semua jenis.
  final String? entityType;

  /// null = semua tindakan.
  final String? action;

  AuditFilter copyWith({
    Object? entityType = _sentinel,
    Object? action = _sentinel,
  }) {
    return AuditFilter(
      entityType: entityType == _sentinel
          ? this.entityType
          : entityType as String?,
      action: action == _sentinel ? this.action : action as String?,
    );
  }

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      other is AuditFilter &&
      other.entityType == entityType &&
      other.action == action;

  @override
  int get hashCode => Object.hash(entityType, action);
}

class AuditLogState {
  const AuditLogState({
    this.logs = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<AuditLog> logs;
  final bool hasMore;
  final bool isLoadingMore;

  AuditLogState copyWith({
    List<AuditLog>? logs,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return AuditLogState(
      logs: logs ?? this.logs,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Jejak audit dengan pagination keyset.
///
/// Guna `before_id` (id terakhir yang diterima) dan bukan offset —
/// jejak audit sentiasa bertambah di hujung atas, jadi offset akan
/// menyebabkan baris berulang/terlangkau semasa pengguna menatal.
class AuditLogNotifier extends FamilyAsyncNotifier<AuditLogState, AuditFilter> {
  @override
  Future<AuditLogState> build(AuditFilter arg) async {
    final logs = await _fetch(beforeId: null);
    return AuditLogState(logs: logs, hasMore: logs.length == _pageSize);
  }

  Future<List<AuditLog>> _fetch({required int? beforeId}) async {
    final res = await ref
        .read(dioProvider)
        .get(
          '/audit-logs',
          queryParameters: {
            'limit': _pageSize,
            'before_id': ?beforeId,
            'entity_type': ?arg.entityType,
            'action': ?arg.action,
          },
        );
    final data = res.data as Map<String, dynamic>;
    return (data['logs'] as List)
        .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        current.logs.isEmpty) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _fetch(beforeId: current.logs.last.id);
      final latest = state.valueOrNull ?? current;
      state = AsyncData(
        latest.copyWith(
          logs: [...latest.logs, ...next],
          hasMore: next.length == _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      final latest = state.valueOrNull ?? current;
      state = AsyncData(latest.copyWith(isLoadingMore: false));
    }
  }
}

final auditLogsProvider =
    AsyncNotifierProvider.family<AuditLogNotifier, AuditLogState, AuditFilter>(
      AuditLogNotifier.new,
    );
