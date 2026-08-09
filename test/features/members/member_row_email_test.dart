import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/profile/profile_providers.dart';

/// `email` nullable sebab backend SEMBUNYIKAN emel ahli lain daripada
/// bukan-management. Membezakan null ("disembunyikan") daripada rentetan
/// kosong penting: yang pertama bermakna kita tak dibenarkan melihatnya,
/// yang kedua akan dipaparkan sebagai baris kosong yang mengelirukan.
void main() {
  test('email tiada dalam JSON → null, bukan rentetan kosong', () {
    final row = MemberRow.fromJson({
      'user_id': '11111111-1111-1111-1111-111111111111',
      'member_id': 'MARC2026/08/0002',
      'display_name': 'Ali',
      'email': null,
      'role_key': 'ahli',
      'role_name': 'Ahli',
      'role_rank': 10,
      'category': 'ahli',
      'status': 'approved',
    });

    expect(row.email, isNull);
    expect(row.email, isNot(''));
  });

  test('email ada → diparse seperti biasa', () {
    final row = MemberRow.fromJson({
      'user_id': '11111111-1111-1111-1111-111111111111',
      'member_id': 'MARC2026/08/0002',
      'display_name': 'Ali',
      'email': 'ali@contoh.com',
      'role_key': 'ahli',
      'role_name': 'Ahli',
      'role_rank': 10,
      'category': 'ahli',
      'status': 'approved',
    });

    expect(row.email, 'ali@contoh.com');
  });

  // Medan yang hilang sepenuhnya (client lama vs backend baharu, atau
  // sebaliknya) tak boleh menyebabkan crash.
  test('kunci email tiada langsung → null', () {
    final row = MemberRow.fromJson({
      'user_id': '11111111-1111-1111-1111-111111111111',
      'member_id': 'MARC2026/08/0002',
      'display_name': null,
      'role_key': 'ahli',
      'role_name': 'Ahli',
      'role_rank': 10,
      'category': 'ahli',
      'status': 'approved',
    });

    expect(row.email, isNull);
  });
}
