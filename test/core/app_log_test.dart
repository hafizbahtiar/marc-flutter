import 'package:flutter_test/flutter_test.dart';
import 'package:marc/core/app_log.dart';

void main() {
  // URL presigned R2 bawa X-Amz-Signature. Ia kredential jangka pendek,
  // tapi tetap kredential - jangan tulis ke log peranti.
  test('query string ditapis daripada URL yang dilog', () {
    final uri = Uri.parse(
      'https://bucket.acct.r2.cloudflarestorage.com/posts/abc.jpg'
      '?X-Amz-Algorithm=AWS4-HMAC-SHA256'
      '&X-Amz-Signature=176f7f99a3b2dfdc2b5bdcbf4611437e',
    );

    final logged = debugSafeUriForTest(uri);

    expect(logged, contains('/posts/abc.jpg'));
    expect(logged, isNot(contains('176f7f99a3b2dfdc2b5bdcbf4611437e')));
    expect(logged, isNot(contains('X-Amz-Signature')));
  });

  test('URL tanpa query kekal utuh', () {
    final uri = Uri.parse('https://api.example.com/posts');
    expect(debugSafeUriForTest(uri), 'https://api.example.com/posts');
  });
}
