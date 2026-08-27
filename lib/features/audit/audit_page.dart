import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/features/audit/audit_models.dart';
import 'package:marc/features/audit/audit_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/utils/relative_time.dart';

/// Jejak audit - management sahaja (backend kuatkuasakan semula 403).
class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});

  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  final _scrollController = ScrollController();
  AuditFilter _filter = const AuditFilter();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(auditLogsProvider(_filter).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bezakan "masih memuat profil" daripada "bukan management". Guna
    // `valueOrNull` sahaja akan pulang null semasa muat, jadi ahli
    // pengurusan yang SAH nampak kilasan "tiada akses" sebelum skrin
    // muncul - corak bug sama yang pernah kosongkan medan emel pada
    // borang donation.
    final profile = ref.watch(myProfileProvider);
    if (profile.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Jejak Audit')),
        body: const SafeArea(
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      );
    }
    if (!(profile.valueOrNull?.isManagement ?? false)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Jejak Audit')),
        body: const SafeArea(
          child: Center(child: Text('Anda tiada akses ke skrin ini.')),
        ),
      );
    }

    final state = ref.watch(auditLogsProvider(_filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Jejak Audit')),
      body: SafeArea(
        child: Column(
          children: [
            _FilterBar(
              filter: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            const Divider(height: 1),
            Expanded(
              child: state.when(
                loading: () => Skeletonizer(
                  enabled: true,
                  child: ListView(
                    children: List.generate(
                      6,
                      (_) => _AuditTile(log: _placeholder),
                    ),
                  ),
                ),
                error: (e, _) => RefreshIndicator.adaptive(
                  onRefresh: () =>
                      ref.refresh(auditLogsProvider(_filter).future),
                  child: ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(child: Text('Gagal memuat jejak audit.')),
                      ),
                    ],
                  ),
                ),
                data: (data) {
                  if (data.logs.isEmpty) {
                    return RefreshIndicator.adaptive(
                      onRefresh: () =>
                          ref.refresh(auditLogsProvider(_filter).future),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 80),
                            child: Center(child: Text('Tiada catatan.')),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator.adaptive(
                    onRefresh: () =>
                        ref.refresh(auditLogsProvider(_filter).future),
                    child: ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount:
                          data.logs.length + (data.isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        if (i >= data.logs.length) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator.adaptive(),
                            ),
                          );
                        }
                        return _AuditTile(log: data.logs[i]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _placeholder = AuditLog(
  id: 0,
  entityType: 'post',
  entityId: '00000000-0000-0000-0000-000000000000',
  action: 'update',
  actorId: '00000000-0000-0000-0000-000000000001',
  actorMemberId: 'MARC2026/08/0000',
  actorRoleKey: 'ahli',
  changedFields: const ['content'],
  oldValues: const {'content': 'kandungan lama'},
  newValues: const {'content': 'kandungan baru'},
  createdAt: DateTime.now(),
);

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final AuditFilter filter;
  final ValueChanged<AuditFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final e in const [
            (null, 'Semua'),
            ('post', 'Post'),
            ('comment', 'Comment'),
            ('profile', 'Ahli'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(e.$2),
                selected: filter.entityType == e.$1,
                onSelected: (_) => onChanged(filter.copyWith(entityType: e.$1)),
              ),
            ),
          const SizedBox(width: 4),
          const _VerticalRule(),
          const SizedBox(width: 12),
          for (final a in const [
            (null, 'Semua'),
            ('update', 'Kemas kini'),
            ('delete', 'Padam'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(a.$2),
                selected: filter.action == a.$1,
                onSelected: (_) => onChanged(filter.copyWith(action: a.$1)),
              ),
            ),
        ],
      ),
    );
  }
}

class _VerticalRule extends StatelessWidget {
  const _VerticalRule();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 24,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.log});

  final AuditLog log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDelete = log.action == 'delete';

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: (isDelete ? scheme.error : scheme.primary).withValues(
          alpha: 0.12,
        ),
        child: Icon(
          switch (log.action) {
            'create' => Icons.add,
            'delete' => Icons.delete_outline,
            _ => Icons.edit_outlined,
          },
          size: 18,
          color: isDelete ? scheme.error : scheme.primary,
        ),
      ),
      title: Text(
        '${log.entityLabel} ${log.actionLabel.toLowerCase()}',
        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              log.actorMemberId ?? 'Sistem',
              if (log.actorRoleKey != null) '(${log.actorRoleKey})',
              '· ${relativeTime(log.createdAt)}',
            ].join(' '),
            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (log.actorId != null)
            SelectableText(
              log.actorId!,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
        ],
      ),
      children: [
        if (log.changedFields.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final f in log.changedFields)
                  Chip(
                    label: Text(
                      AuditLog.fieldLabel(f),
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        for (final field in _fieldsToShow(log))
          _DiffRow(
            field: field,
            before: log.oldValues?[field],
            after: log.newValues?[field],
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(
            'ID entiti: ${log.entityId}',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  /// Untuk 'update', changed_fields dah menyenaraikan apa yang berubah.
  /// Untuk 'create'/'delete' backend simpan snapshot penuh, jadi ambil
  /// kunci daripada sisi yang ada.
  static List<String> _fieldsToShow(AuditLog log) {
    if (log.changedFields.isNotEmpty) return log.changedFields;
    final source = log.newValues ?? log.oldValues ?? const {};
    return source.keys.toList()..sort();
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({required this.field, this.before, this.after});

  final String field;
  final Object? before;
  final Object? after;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget value(Object? v, {required bool removed}) {
      if (v == null) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: (removed ? scheme.error : scheme.primary).withValues(
            alpha: 0.08,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              width: 3,
              color: removed ? scheme.error : scheme.primary,
            ),
          ),
        ),
        child: Text('$v', style: textTheme.bodySmall),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AuditLog.fieldLabel(field),
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          value(before, removed: true),
          value(after, removed: false),
        ],
      ),
    );
  }
}
