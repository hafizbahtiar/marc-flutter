import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/activities/activity_format.dart';
import 'package:marc/features/activities/activity_models.dart';
import 'package:marc/features/activities/activity_providers.dart';
import 'package:marc/features/activities/manage/manage_providers.dart';
import 'package:marc/shared/widgets/approval_gate.dart';

/// Baris hantu untuk Skeletonizer semasa memuat — corak sama dengan
/// `_placeholderRow` dalam members_page.dart.
final _placeholderActivity = Activity(
  id: '00000000-0000-0000-0000-000000000000',
  title: 'Kejohanan Badminton Tahunan',
  description: '',
  categoryId: '',
  categoryName: 'Sukan',
  locationName: 'Dewan Serbaguna MARC',
  locationAddress: '',
  startsAt: DateTime.now(),
  endsAt: DateTime.now(),
  registrationClosesAt: DateTime.now(),
  capacity: 30,
  registrationCount: 12,
  status: 'published',
  sessions: const [],
  isRegistered: false,
);

/// Gate `approved` (padanan `approved.GET("/activities")` backend) diletak
/// DI LUAR isi kandungan sebenar — sama rasional dengan
/// `NotificationsPage` (lihat komen di sana): provider aktiviti hanya
/// di-watch bila `_ActivitiesContent` betul-betul dibina, elak panggilan
/// 403 langsung untuk ahli `pending`.
class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApprovalGate(title: 'Aktiviti', child: _ActivitiesContent());
  }
}

class _ActivitiesContent extends ConsumerStatefulWidget {
  const _ActivitiesContent();

  @override
  ConsumerState<_ActivitiesContent> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends ConsumerState<_ActivitiesContent> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(activitiesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(activityFilterProvider);
    final activities = ref.watch(activitiesProvider);
    // Kemudahan UI sahaja — backend menolak `status=draft` dan setiap
    // route pengurusan dengan 403 untuk bukan-pengurusan.
    final isManagement = ref.watch(isManagementProvider);

    return Scaffold(
      floatingActionButton: isManagement
          ? FloatingActionButton.extended(
              // heroTag unik — lihat komen padanan di feed_page.dart.
              heroTag: 'activities-fab',
              onPressed: () => context.push('/activities/new'),
              icon: const Icon(Icons.add),
              label: const Text('Aktiviti'),
            )
          : null,
      appBar: AppBar(
        title: const Text('Aktiviti'),
        actions: [
          if (isManagement)
            IconButton(
              tooltip: filter.drafts ? 'Papar semua' : 'Papar draf sahaja',
              isSelected: filter.drafts,
              icon: const Icon(Icons.edit_note_outlined),
              selectedIcon: const Icon(Icons.edit_note),
              onPressed: () {
                ref.read(activityFilterProvider.notifier).state = filter
                    .copyWith(drafts: !filter.drafts);
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              _UpcomingTabs(
                upcoming: filter.upcoming,
                onChanged: (upcoming) {
                  ref.read(activityFilterProvider.notifier).state = filter
                      .copyWith(upcoming: upcoming);
                },
              ),
              const _CategoryChips(),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: activities.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: ListView(
              children: [
                for (var i = 0; i < 5; i++)
                  _ActivityCard(activity: _placeholderActivity, onTap: () {}),
              ],
            ),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Gagal memuat senarai aktiviti.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(activitiesProvider.notifier).refresh(),
                    child: const Text('Cuba lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (state) {
            if (state.activities.isEmpty) {
              return RefreshIndicator.adaptive(
                onRefresh: () => ref.read(activitiesProvider.notifier).refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 100),
                      child: Center(
                        child: Text(
                          filter.drafts
                              ? 'Tiada draf aktiviti.'
                              : filter.upcoming
                              ? 'Tiada aktiviti akan datang buat masa ini.'
                              : 'Tiada aktiviti lepas.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: () => ref.read(activitiesProvider.notifier).refresh(),
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: state.activities.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.activities.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator.adaptive()),
                    );
                  }
                  final activity = state.activities[index];
                  return _ActivityCard(
                    activity: activity,
                    onTap: () => context.push('/activities/${activity.id}'),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _UpcomingTabs extends StatelessWidget {
  const _UpcomingTabs({required this.upcoming, required this.onChanged});

  final bool upcoming;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('Akan Datang')),
          ButtonSegment(value: false, label: Text('Lepas')),
        ],
        selected: {upcoming},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(activityCategoriesProvider);
    final filter = ref.watch(activityFilterProvider);

    // Kategori gagal dimuat bukan sebab untuk mematikan seluruh halaman —
    // senarai aktiviti masih berfungsi tanpa cip penapis.
    final rows = categories.valueOrNull ?? const <ActivityCategory>[];
    if (rows.isEmpty) return const SizedBox(height: 48);

    void select(String? id) {
      ref.read(activityFilterProvider.notifier).state = filter.copyWith(
        categoryId: () => id,
      );
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          ChoiceChip(
            label: const Text('Semua'),
            selected: filter.categoryId == null,
            onSelected: (_) => select(null),
          ),
          for (final c in rows) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(c.name),
              selected: filter.categoryId == c.id,
              onSelected: (_) => select(c.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.onTap});

  final Activity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      activity.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (activity.isRegistered)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.check_circle, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              _IconLine(
                icon: Icons.event_outlined,
                text: formatDateTime(activity.startsAt),
              ),
              if (activity.locationName.isNotEmpty)
                _IconLine(
                  icon: Icons.place_outlined,
                  text: activity.locationName,
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (activity.categoryName.isNotEmpty)
                    _Tag(label: activity.categoryName),
                  _SlotsBadge(activity: activity),
                  if (activity.isCancelled)
                    _Tag(
                      label: 'Dibatalkan',
                      color: theme.colorScheme.error,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(color: fg),
      ),
    );
  }
}

/// Kiraan slot. `capacity == null` bermakna TIADA had — bukan sifar slot,
/// jadi ia dipapar sebagai "Terbuka" dan bukan "0 slot".
class _SlotsBadge extends StatelessWidget {
  const _SlotsBadge({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final left = activity.slotsLeft;

    if (left == null) {
      return _Tag(label: '${activity.registrationCount} pendaftaran');
    }
    if (left == 0) {
      return _Tag(label: 'Penuh', color: theme.colorScheme.error);
    }
    return _Tag(
      label: '$left slot tinggal',
      color: left <= 3
          ? theme.extension<AppSemanticColors>()!.warning
          : null,
    );
  }
}
