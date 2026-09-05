import 'package:marc/features/profile/profile_providers.dart';

/// Pemalar `Profile` dikongsi untuk ujian - dimodelkan pada `_member` dalam
/// `test/features/notifications/notifications_page_test.dart`. Diletak
/// dalam `test/support/` supaya ujian lain (dashboard, dsb.) boleh guna
/// semula tanpa duplikasi.
const approvedProfile = Profile(
  memberId: 'MARC-001',
  email: 'ahli@example.com',
  emailVerified: true,
  status: 'approved',
  displayName: 'Ahli',
  phone: null,
  roleKey: 'member',
  roleName: 'Ahli',
  roleRank: 1,
  category: 'member',
  telegramLinked: false,
);

/// Sama seperti [approvedProfile] tapi `status: 'pending'` - untuk ujian
/// laluan "belum layak" (cth `dashboardProvider` tidak memanggil
/// `/dashboard` untuk ahli pending).
const pendingProfile = Profile(
  memberId: null,
  email: 'pending@example.com',
  emailVerified: true,
  status: 'pending',
  displayName: 'Ahli Pending',
  phone: null,
  roleKey: 'member',
  roleName: 'Ahli',
  roleRank: 1,
  category: 'member',
  telegramLinked: false,
);
