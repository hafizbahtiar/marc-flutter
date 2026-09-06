import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/features/activities/manage/management_gate.dart';
import 'package:marc/features/admin/banned_members_models.dart';
import 'package:marc/features/admin/banned_members_providers.dart';
import 'package:marc/features/profile/profile_providers.dart';
import 'package:marc/shared/ui/dialog/confirm_dialog.dart';
import 'package:marc/shared/ui/widgets/my_snackbar.dart';

class BannedMembersPage extends ConsumerWidget {
  const BannedMembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ManagementGate(
      title: 'Akaun Digantung',
      child: ref.watch(isSuperAdminProvider)
          ? const _BannedMembersBody()
          : const Scaffold(
              appBar: _BannedMembersAppBar(),
              body: Center(child: Text('Skrin ini untuk superadmin sahaja.')),
            ),
    );
  }
}

class _BannedMembersAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _BannedMembersAppBar();

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('Akaun Digantung'));

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _BannedMembersBody extends ConsumerWidget {
  const _BannedMembersBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bannedMembersProvider);
    return Scaffold(
      appBar: const _BannedMembersAppBar(),
      body: SafeArea(
        child: state.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Gagal memuat akaun yang digantung.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(bannedMembersProvider),
                  child: const Text('Cuba lagi'),
                ),
              ],
            ),
          ),
          data: (members) => DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Permanent'),
                    Tab(text: 'Tidak permanent'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _BannedList(
                        members: members
                            .where((member) => member.isPermanent)
                            .toList(),
                      ),
                      _BannedList(
                        members: members
                            .where((member) => !member.isPermanent)
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannedList extends ConsumerWidget {
  const _BannedList({required this.members});

  final List<BannedMember> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (members.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => ref.invalidate(bannedMembersProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Tiada akaun dalam kategori ini.')),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(bannedMembersProvider),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: members.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _BannedTile(member: members[index]),
      ),
    );
  }
}

class _BannedTile extends ConsumerWidget {
  const _BannedTile({required this.member});

  final BannedMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expires = member.expiresAt == null
        ? 'Tiada tamat'
        : 'Tamat ${_formatDate(member.expiresAt!)}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      title: Text(
        member.displayName?.trim().isNotEmpty == true
            ? member.displayName!
            : 'Tanpa nama',
      ),
      subtitle: Text('${member.email}\n${member.reason}\n$expires'),
      isThreeLine: true,
      trailing: OutlinedButton(
        onPressed: () => _unban(context, ref),
        child: const Text('Buka ban'),
      ),
    );
  }

  Future<void> _unban(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Buka penggantungan',
      message: 'Benarkan ${member.email} mengakses MARC semula?',
      confirmLabel: 'Buka ban',
    );
    if (!ok || !context.mounted) return;
    final error = await ref
        .read(bannedMembersRepositoryProvider)
        .unban(member.userId);
    if (!context.mounted) return;
    if (error == null) {
      MySnackBar.success(context, 'Penggantungan akaun telah dibuka.');
    } else {
      MySnackBar.error(context, error);
    }
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month}/${local.year} '
      '${local.hour}:$minute';
}
