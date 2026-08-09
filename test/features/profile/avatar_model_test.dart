import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/posts/post_models.dart';
import 'package:marc/features/profile/profile_providers.dart';

Map<String, dynamic> _profileJson({Object? avatar = _absent}) => {
  'member_id': 'MARC2026/08/0001',
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
        'member_id': 'MARC2026/08/0002',
        'display_name': 'Ali',
        'avatar_url': 'https://x/b.jpg',
      });
      expect(a.avatarUrl, 'https://x/b.jpg');

      final none = Author.fromJson({
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
}
