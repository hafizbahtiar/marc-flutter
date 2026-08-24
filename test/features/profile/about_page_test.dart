import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/profile/about_page.dart';
import 'package:marc/features/profile/faq_page.dart';

/// Penafian "bukan rasmi" ialah dakwaan ketepatan, bukan hiasan: app yang
/// ada logo, senarai ahli dan pengumuman memang mudah dibaca sebagai
/// rasmi, dan halaman sumbangan pula bergantung pada perbezaan ni (derma
/// pergi kepada pembangun, BUKAN kepada MAIWP). Ujian ni ada supaya ia tak
/// hilang senyap semasa kemas kini teks.
void main() {
  testWidgets('Tentang: nyatakan bukan rasmi, tiada dakwaan "aplikasi rasmi"', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AboutPage()),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('bukan aplikasi rasmi MAIWP'),
      findsOneWidget,
      reason: 'penafian hilang',
    );
    expect(
      find.textContaining('tidak diurus, ditaja atau disahkan'),
      findsOneWidget,
    );

    // Dakwaan lama tak boleh kembali dalam apa jua bentuk.
    expect(
      find.textContaining('aplikasi rasmi untuk ahli MAIWP'),
      findsNothing,
    );
    expect(find.textContaining('© ${DateTime.now().year} MAIWP'), findsNothing);
    expect(
      find.textContaining('© ${DateTime.now().year} Hafiz Bahtiar'),
      findsOneWidget,
    );
  });

  testWidgets('FAQ: ada soalan "adakah ini rasmi" dengan jawapan bukan', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const FaqPage()),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Adakah MARC aplikasi rasmi MAIWP?'),
      findsOneWidget,
    );

    // Kelulusan pendaftaran dibuat oleh pengurusan MARC, bukan MAIWP -
    // menyebut MAIWP di sini menyiratkan pengendalian rasmi.
    expect(
      find.textContaining('diluluskan oleh pihak pengurusan MAIWP'),
      findsNothing,
    );
  });

  testWidgets('Tentang: kredit En. Ezri sebagai pencetus', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AboutPage()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('En. Ezri'), findsOneWidget);
    expect(find.textContaining('secara sukarela'), findsWidgets);
  });
}
