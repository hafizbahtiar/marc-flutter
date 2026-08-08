import 'package:flutter/material.dart';
import 'package:marc/app/theme.dart';

class _Faq {
  const _Faq(this.question, this.answer);

  final String question;
  final String answer;
}

const _faqs = [
  _Faq(
    'Bagaimana cara mendaftar sebagai ahli MARC?',
    'Daftar guna emel anda dalam skrin pendaftaran. Pendaftaran anda '
        'perlu diluluskan oleh pihak pengurusan MAIWP sebelum anda boleh '
        'mengakses ciri penuh app.',
  ),
  _Faq(
    'Kenapa saya masih tidak boleh akses feed selepas daftar?',
    'Dua sebab: (1) pendaftaran anda masih menunggu kelulusan pengurusan, '
        'atau (2) emel anda belum disahkan. Semak halaman utama untuk status '
        'terkini dan pautan hantar semula emel pengesahan.',
  ),
  _Faq(
    'Bagaimana cara sahkan emel saya?',
    'Selepas daftar/log masuk, pautan pengesahan akan dihantar ke emel '
        'anda. Kalau tak jumpa, semak folder spam atau guna butang "Hantar '
        'semula" pada skrin pengesahan emel.',
  ),
  _Faq(
    'Apa beza role Ahli, Supervisor, Manager, dan Super Admin?',
    'Ahli ialah role asas semua pengguna. Supervisor, Manager, dan Super '
        'Admin ialah role pengurusan dengan kebenaran tambahan seperti '
        'meluluskan ahli baru dan menukar role ahli lain, mengikut hierarki '
        'organisasi.',
  ),
  _Faq(
    'Bagaimana cara buat post baru?',
    'Tekan butang + pada skrin utama, tulis kandungan atau lampirkan '
        'gambar (maksimum 4 keping, 5MB sekeping), kemudian tekan Hantar.',
  ),
  _Faq(
    'Kenapa saya tidak boleh tukar role ahli lain?',
    'Cuma pengurusan (Supervisor ke atas) boleh tukar role, dan hanya '
        'untuk ahli dengan rank lebih rendah drpd anda. Anda juga tidak '
        'boleh tukar role akaun sendiri.',
  ),
  _Faq(
    'Saya ada masalah lain, macam mana nak hubungi pihak pengurusan?',
    'Sila hubungi pihak pengurusan MAIWP secara terus melalui saluran '
        'rasmi MAIWP di luar app ini.',
  ),
];

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soalan Lazim')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _faqs.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final faq = _faqs[i];
            return ExpansionTile(
              title: Text(
                faq.question,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              iconColor: AppColors.accent,
              collapsedIconColor: AppColors.muted,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faq.answer,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
