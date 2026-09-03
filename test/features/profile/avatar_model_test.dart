import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/members/member_detail_model.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/features/profile/profile_providers.dart';

Map<String, dynamic> _profileJson({
  Object? avatar = _absent,
  Object? memberId = 'MARC2026/08/0001',
}) => {
  if (memberId != _absent) 'member_id': memberId,
  'email': 'a@b.com',
  'email_verified': true,
  'status': 'approved',
  'display_name': 'Hafiz',
  'phone': null,
  'role_key': 'ahli',
  'role_name': 'Ahli',
  'role_rank': 10,
  'category': 'ahli',
  if (avatar != _absent) 'avatar_url': avatar,
};

const _absent = Object();

void main() {
  group('avatar_url diparse merentas model', () {
    test('Profile: ada / null / medan tiada langsung', () {
      expect(
        Profile.fromJson(_profileJson(avatar: 'https://x/a.jpg')).avatarUrl,
        'https://x/a.jpg',
      );
      expect(Profile.fromJson(_profileJson(avatar: null)).avatarUrl, isNull);
      // Client lama vs backend baharu (atau sebaliknya) tak boleh ranap.
      expect(Profile.fromJson(_profileJson()).avatarUrl, isNull);
    });

    test('Author: dihantar pada setiap post/comment (elak N+1)', () {
      final a = Author.fromJson({
        'user_id': 'user-ali',
        'member_id': 'MARC2026/08/0002',
        'display_name': 'Ali',
        'avatar_url': 'https://x/b.jpg',
      });
      expect(a.avatarUrl, 'https://x/b.jpg');

      final none = Author.fromJson({
        'user_id': 'user-ali',
        'member_id': 'MARC2026/08/0002',
        'display_name': 'Ali',
      });
      expect(none.avatarUrl, isNull);
    });

    test('MemberRow', () {
      final row = MemberRow.fromJson({
        'user_id': '11111111-1111-1111-1111-111111111111',
        'member_id': 'MARC2026/08/0003',
        'display_name': 'Siti',
        'email': null,
        'role_key': 'ahli',
        'role_name': 'Ahli',
        'role_rank': 10,
        'category': 'ahli',
        'status': 'approved',
        'avatar_url': 'https://x/c.jpg',
      });
      expect(row.avatarUrl, 'https://x/c.jpg');
    });
  });

  test('Profile.copyWith boleh kosongkan avatar', () {
    final p = Profile.fromJson(_profileJson(avatar: 'https://x/a.jpg'));
    expect(p.copyWith(avatarUrl: null).avatarUrl, isNull);
    // Tanpa argumen = tak berubah (sentinel, bukan null).
    expect(p.copyWith().avatarUrl, 'https://x/a.jpg');
  });

  // member_id jadi nullable lepas verifikasi staff (ditangguh sampai
  // verified). Client mesti tak ranap bila kunci tiada / null - backend
  // baharu pulang null untuk ahli pending yang belum disahkan.
  group('memberId nullable merentas model', () {
    test('Profile: memberId is null when member_id key is absent', () {
      final profile = Profile.fromJson(_profileJson(memberId: _absent));
      expect(profile.memberId, isNull);
    });

    test('Profile: memberId is null when member_id is JSON null', () {
      expect(Profile.fromJson(_profileJson(memberId: null)).memberId, isNull);
    });

    test('MemberRow: memberId is null when member_id key is absent', () {
      final row = MemberRow.fromJson({
        'user_id': '11111111-1111-1111-1111-111111111111',
        'display_name': 'Siti',
        'role_key': 'ahli',
        'role_name': 'Ahli',
        'role_rank': 10,
        'category': 'ahli',
        'status': 'pending',
      });
      expect(row.memberId, isNull);
    });

    test('Author: memberId is null when member_id key is absent', () {
      final a = Author.fromJson({'user_id': 'user-ali', 'display_name': 'Ali'});
      expect(a.memberId, isNull);
    });

    test('Author.label jatuh ke Belum disahkan bila memberId null', () {
      final a = Author.fromJson({'user_id': 'user-ali', 'display_name': null});
      expect(a.label, 'Belum disahkan');
    });

    test('MemberDetail: memberId is null when member_id key is absent', () {
      final d = MemberDetail.fromJson({
        'user_id': 'user-1',
        'display_name': 'Aina',
        'role_key': 'ahli',
        'role_name': 'Ahli',
        'role_rank': 10,
        'category': 'ahli',
        'status': 'pending',
      });
      expect(d.memberId, isNull);
    });

    test('rentetan kosong member_id dianggap null merentas model', () {
      expect(Profile.fromJson(_profileJson(memberId: '')).memberId, isNull);
      expect(Profile.fromJson(_profileJson(memberId: '   ')).memberId, isNull);

      final row = MemberRow.fromJson({
        'user_id': '11111111-1111-1111-1111-111111111111',
        'member_id': '',
        'display_name': 'Siti',
        'role_key': 'ahli',
        'role_name': 'Ahli',
        'role_rank': 10,
        'category': 'ahli',
        'status': 'pending',
      });
      expect(row.memberId, isNull);

      final a = Author.fromJson({
        'user_id': 'user-ali',
        'member_id': '',
        'display_name': null,
      });
      expect(a.memberId, isNull);
      expect(a.label, 'Belum disahkan');

      final d = MemberDetail.fromJson({
        'user_id': 'user-1',
        'member_id': '',
        'display_name': 'Aina',
        'role_key': 'ahli',
        'role_name': 'Ahli',
        'role_rank': 10,
        'category': 'ahli',
        'status': 'pending',
      });
      expect(d.memberId, isNull);
    });
  });
}
