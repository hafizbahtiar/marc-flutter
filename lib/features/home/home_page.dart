import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc_flutter/app/theme.dart';
import 'package:marc_flutter/features/auth/auth_providers.dart';
import 'package:marc_flutter/features/profile/profile_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log keluar',
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Anda telah log masuk',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(email, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),
              _MemberIdCard(
                child: profile.when(
                  loading: () => const _MemberIdText(value: '…'),
                  error: (_, _) => const _MemberIdText(value: '—'),
                  data: (p) => _MemberIdText(value: p?.memberId ?? '—'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberIdCard extends StatelessWidget {
  const _MemberIdCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NO. AHLI',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                  letterSpacing: 1.5,
                ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _MemberIdText extends StatelessWidget {
  const _MemberIdText({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.accentDark,
          ),
    );
  }
}
