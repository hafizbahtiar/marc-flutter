import 'package:flutter_test/flutter_test.dart';

import 'fake_draft_repository.dart';

void main() {
  test(
    'FakeDraftRepository: get/save/delete roundtrip macam repo sebenar',
    () async {
      final repo = FakeDraftRepository();

      expect(await repo.get('k'), isNull);

      await repo.save('k', kind: 'post', content: 'hai', isAnnouncement: false);
      final draft = await repo.get('k');
      expect(draft!.content, 'hai');
      expect(draft.isAnnouncement, isFalse);

      await repo.delete('k');
      expect(await repo.get('k'), isNull);
    },
  );
}
