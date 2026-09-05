import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/app/nav_shell.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/features/auth/forgot_password_page.dart';
import 'package:marc/features/auth/login_page.dart';
import 'package:marc/features/auth/register_page.dart';
import 'package:marc/features/activities/activities_page.dart';
import 'package:marc/features/activities/activity_detail_page.dart';
import 'package:marc/features/activities/my_activities_page.dart';
import 'package:marc/features/activities/my_certificates_page.dart';
import 'package:marc/features/activities/manage/activity_categories_page.dart';
import 'package:marc/features/admin/blocked_email_domains_page.dart';
import 'package:marc/features/admin/departments_page.dart';
import 'package:marc/features/activities/manage/activity_form_page.dart';
import 'package:marc/features/activities/manage/issue_certificates_page.dart';
import 'package:marc/features/activities/manage/checkin_scanner_page.dart';
import 'package:marc/features/activities/manage/registrations_page.dart';
import 'package:marc/features/activities/manage/session_checkin_qr_page.dart';
import 'package:marc/features/activities/self_checkin_scanner_page.dart';
import 'package:marc/features/audit/audit_page.dart';
import 'package:marc/features/checkout/checkout_page.dart';
import 'package:marc/features/dashboard/dashboard_page.dart';
import 'package:marc/features/donation/donation_page.dart';
import 'package:marc/features/members/member_detail_page.dart';
import 'package:marc/features/members/members_page.dart';
import 'package:marc/features/members/pending_members_page.dart';
import 'package:marc/features/notifications/notifications_page.dart';
import 'package:marc/features/payments/admin_payments_page.dart';
import 'package:marc/features/payments/payment_history_page.dart';
import 'package:marc/features/posts/create_post_page.dart';
import 'package:marc/features/posts/feed_page.dart';
import 'package:marc/features/posts/post_detail_page.dart';
import 'package:marc/features/profile/about_page.dart';
import 'package:marc/features/profile/active_sessions_page.dart';
import 'package:marc/features/profile/address_form_page.dart';
import 'package:marc/features/profile/address_providers.dart';
import 'package:marc/features/profile/edit_profile_page.dart';
import 'package:marc/features/profile/faq_page.dart';
import 'package:marc/features/profile/manage_addresses_page.dart';
import 'package:marc/features/profile/profile_page.dart';
import 'package:marc/features/profile/settings_page.dart';
import 'package:marc/features/profile/telegram_link_page.dart';
import 'package:marc/shared/ui/map/map_page.dart';
import 'package:marc/shared/ui/widgets/web_view_page.dart';

/// Adapter: dengar perubahan authNotifierProvider, notify GoRouter untuk
/// refresh redirect. Gantian `GoRouterRefreshStream` yang dulu dengar
/// stream Supabase `onAuthStateChange`.
class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    _sub = ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (previous?.isLoggedIn != next.isLoggedIn) notifyListeners();
    });
  }

  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _GoRouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authNotifierProvider).isLoggedIn;
      final loc = state.matchedLocation;
      final onAuthPage =
          loc == '/login' || loc == '/register' || loc == '/forgot-password';
      if (loggedIn && onAuthPage) return '/dashboard';
      if (!loggedIn && !onAuthPage) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (_, _) => const EditProfilePage(),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(
        path: '/profile/addresses',
        builder: (_, _) => const ManageAddressesPage(),
      ),
      // '/profile/addresses/new' MESTI didahulukan drpd
      // '/profile/addresses/:id/edit' - go_router memadan mengikut
      // urutan (sama sebab dengan '/activities/new' di bawah).
      GoRoute(
        path: '/profile/addresses/new',
        builder: (_, _) => const AddressFormPage(),
      ),
      GoRoute(
        path: '/profile/addresses/:id/edit',
        builder: (_, state) =>
            AddressFormPage(existing: state.extra! as AddressRow),
      ),
      GoRoute(
        path: '/profile/sessions',
        builder: (_, _) => const ActiveSessionsPage(),
      ),
      GoRoute(path: '/map', builder: (_, _) => const MapPage()),
      GoRoute(path: '/about', builder: (_, _) => const AboutPage()),
      GoRoute(path: '/faq', builder: (_, _) => const FaqPage()),
      GoRoute(
        path: '/legal/:doc',
        builder: (_, state) {
          final doc = state.pathParameters['doc']!;
          final title = switch (doc) {
            'terma-dan-syarat' => 'Terma & Syarat',
            'dasar-privasi' => 'Dasar Privasi',
            _ => 'Dokumen',
          };
          return WebViewPage(
            title: title,
            url: 'https://marc.hafizbahtiar.com/$doc',
          );
        },
      ),
      GoRoute(path: '/donate', builder: (_, _) => const DonationPage()),
      GoRoute(
        path: '/checkout',
        // `extra` (bukan path param) sebab `CheckoutRequest.onCheckout`
        // ialah closure - tak boleh diserialize ke URL. Ni bermakna
        // route ni BOLEH dicapai dengan `extra` null/salah jenis kalau
        // deep-link `marc://...` cetuskan navigasi terus ke `/checkout`
        // (skim `marc` didaftar utk Stripe redirect,
        // `flutter_deeplinking_enabled` lalai ON) - redirect (bukan `!`
        // yang crash) ke `/dashboard` untuk kes tu, Opus verify 2026-08-24.
        redirect: (_, state) =>
            state.extra is CheckoutRequest ? null : '/dashboard',
        builder: (_, state) =>
            CheckoutPage(request: state.extra! as CheckoutRequest),
      ),
      GoRoute(
        path: '/telegram-link',
        builder: (_, _) => const TelegramLinkPage(),
      ),
      GoRoute(
        path: '/members',
        // `extra` (opsyenal) - kod bahagian awal utk penapis direktori,
        // dihantar drpd chip bahagian di `MemberDetailPage`. Nullable
        // (BUKAN `!`) sebab `/members` boleh dicapai tanpa `extra` sama
        // sekali (navigasi biasa drpd nav bawah/menu) - beza dgn
        // `/checkout` di atas yang mesti ada `extra`.
        builder: (_, state) =>
            MembersPage(initialDepartmentCode: state.extra as String?),
      ),
      GoRoute(path: '/audit-logs', builder: (_, _) => const AuditPage()),
      GoRoute(
        path: '/admin/blocked-email-domains',
        builder: (_, _) => const BlockedEmailDomainsPage(),
      ),
      GoRoute(
        path: '/admin/departments',
        builder: (_, _) => const DepartmentsPage(),
      ),
      GoRoute(
        path: '/payments/history',
        builder: (_, _) => const PaymentHistoryPage(),
      ),
      GoRoute(
        path: '/admin/payments',
        builder: (_, _) => const AdminPaymentsPage(),
      ),
      // MESTI didahulukan drpd '/members/:userId' di bawah - sama sebab
      // dengan '/activities/new' vs '/activities/:id' di bawah (go_router
      // memadan mengikut urutan, laluan statik dulu).
      GoRoute(
        path: '/members/pending',
        builder: (_, _) => const PendingMembersPage(),
      ),
      // Skrin profil SATU ahli (view-only, tiered) - di LUAR shell (sama
      // macam /posts/:id, /activities/:id) supaya ditolak penuh skrin
      // dengan butang kembali.
      GoRoute(
        path: '/members/:userId',
        builder: (_, state) =>
            MemberDetailPage(userId: state.pathParameters['userId']!),
      ),
      GoRoute(path: '/posts/new', builder: (_, _) => const CreatePostPage()),
      GoRoute(
        path: '/posts/:id',
        builder: (_, state) =>
            PostDetailPage(postId: state.pathParameters['id']!),
      ),
      // Laluan sendiri, BUKAN '/activities/...': '/activities/:id'
      // menangkap apa-apa segmen tunggal, jadi '/activities/saya' akan
      // dihantar ke halaman detail sebagai id "saya".
      GoRoute(
        path: '/my-activities',
        builder: (_, _) => const MyActivitiesPage(),
      ),
      GoRoute(
        path: '/my-certificates',
        builder: (_, _) => const MyCertificatesPage(),
      ),
      // Skrin PENGURUSAN. '/activities/new' MESTI didahulukan daripada
      // '/activities/:id' - go_router memadan mengikut urutan, jadi
      // pertukaran susunan akan menghantar "new" ke halaman detail
      // sebagai id.
      GoRoute(
        path: '/activities/new',
        builder: (_, _) => const ActivityFormPage(),
      ),
      // MESTI didahulukan drpd '/activities/:id' - sama sebab dengan
      // '/activities/new' di atas.
      GoRoute(
        path: '/activities/categories',
        builder: (_, _) => const ActivityCategoriesPage(),
      ),
      GoRoute(
        path: '/activities/:id/edit',
        builder: (_, state) =>
            ActivityFormPage(activityId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/activities/:id/registrations',
        builder: (_, state) =>
            RegistrationsPage(activityId: state.pathParameters['id']!),
      ),
      // Sesi dipilih pada skrin Senarai Peserta dan dikunci pada route -
      // pengimbas tidak mempunyai pemilih sesi sendiri, kerana satu
      // ketukan tersilap di sana menanda barisan penuh pada sesi salah.
      GoRoute(
        path: '/activities/:id/sessions/:sid/scan',
        builder: (_, state) => CheckinScannerPage(
          activityId: state.pathParameters['id']!,
          sessionId: state.pathParameters['sid']!,
        ),
      ),
      GoRoute(
        path: '/activities/:id/sessions/:sid/checkin-qr',
        builder: (_, state) => SessionCheckinQrPage(
          activityId: state.pathParameters['id']!,
          sessionId: state.pathParameters['sid']!,
        ),
      ),
      // Tiada parameter - sesi/aktiviti datang drpd kandungan QR yang
      // diimbas, bukan route (lihat komen SelfCheckinScannerPage).
      GoRoute(
        path: '/checkin',
        builder: (_, _) => const SelfCheckinScannerPage(),
      ),
      GoRoute(
        path: '/activities/:id/certificates',
        builder: (_, state) =>
            IssueCertificatesPage(activityId: state.pathParameters['id']!),
      ),
      // Detail aktiviti di LUAR shell (sama macam /posts/:id) supaya ia
      // ditolak penuh skrin dengan butang kembali, bukan terkurung dalam
      // tab dengan bottom nav yang masih kelihatan.
      GoRoute(
        path: '/activities/:id',
        builder: (_, state) =>
            ActivityDetailPage(activityId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => NavShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, _) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/feed', builder: (_, _) => const FeedPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activities',
                builder: (_, _) => const ActivitiesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (_, _) => const NotificationsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
            ],
          ),
        ],
      ),
    ],
  );
});
