import 'package:flutter/material.dart';
import 'package:marc/shared/ui/map/transit_overlay.dart';
import 'package:marc/shared/ui/sheet/app_info_sheet.dart';

/// Jenis hari yang feed Prasarana guna, mengikut susunan paparan.
const _serviceDays = {
  'MonFri': 'Isnin - Jumaat',
  'Sat': 'Sabtu',
  'Sun': 'Ahad',
};

/// Kad butiran stesen, dalam [AppInfoSheet] supaya peta di belakangnya
/// kekal boleh dileret semasa ia dibaca.
class TransitStationCard extends StatelessWidget {
  const TransitStationCard({
    super.key,
    required this.station,
    required this.onClose,
  });

  final TransitStation station;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Satu senarai, satu entri setiap laluan - bukan senarai cip di atas
    // DAN senarai jadual di bawah yang menamakan laluan sama dua kali.
    final byRoute = <String, List<TransitStationLine>>{};
    for (final line in station.lines) {
      (byRoute[line.route] ??= []).add(line);
    }
    final routes = station.routes.isEmpty
        ? byRoute.keys.toList()
        : station.routes;

    return AppInfoSheet(
      title: station.name,
      subtitle: _subtitle(),
      onClose: onClose,
      children: [
        for (final route in routes)
          _RouteBlock(
            code: route,
            name: station.labelOf(route),
            color: parseTransitColor(station.colorOf(route), scheme.primary),
            directions: byRoute[route] ?? const [],
          ),
        if (station.lines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            // Tren terakhir diterbitkan, bukan diterbitkan oleh Prasarana.
            // Membentangkannya tanpa label ini bermakna seseorang boleh
            // terlepas tren terakhir kerana kad ni.
            child: Text(
              'Waktu tren terakhir ialah anggaran, dikira dari waktu tamat '
              'perkhidmatan di stesen permulaan.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  /// Metadata sebagai satu baris di bawah nama, bukan baris berasingan
  /// dalam badan - ia mengenal pasti stesen, bukan menerangkannya.
  String _subtitle() {
    final parts = <String>[
      if (station.interchange) 'Pertukaran · ${station.routes.length} laluan',
      station.oku ? 'Akses OKU' : 'Tiada akses OKU',
    ];
    return parts.join(' · ');
  }
}

/// Satu laluan pada stesen ni, dengan setiap arahnya.
class _RouteBlock extends StatelessWidget {
  const _RouteBlock({
    required this.code,
    required this.name,
    required this.color,
    required this.directions,
  });

  final String code;
  final String name;
  final Color color;
  final List<TransitStationLine> directions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rel warna laluan - satu peranti visual untuk identiti laluan,
            // bukan cip berwarna DAN bar berwarna yang mengatakan perkara
            // sama dua kali.
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          code,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: transitOnColor(color),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (final direction in directions) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Ke ${direction.terminus}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final entry in _serviceDays.entries)
                      if (_hours(direction, entry.key) case final hours?)
                        _ServiceRow(
                          day: entry.value,
                          hours: hours,
                          frequency: _frequency(direction, entry.key),
                        ),
                  ],
                  if (directions.isEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Jadual tidak tersedia.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Null bila feed tiada bukti perkhidmatan pada hari itu.
  ///
  /// `first` sama merentas jenis hari, jadi ia SAHAJA tak membuktikan hari
  /// itu beroperasi. Memaparkannya atas dasar itu akan mengarang
  /// perkhidmatan Ahad untuk laluan yang tak beroperasi hari Ahad.
  static String? _hours(TransitStationLine line, String service) {
    final last = line.last[service];
    final headway = line.frequency[service];
    if (last == null && headway == null) return null;

    final first = line.first;
    if (first != null && last != null) return '$first - $last';
    if (first != null) return 'mula $first';
    if (last != null) return 'tamat $last';
    return null;
  }

  static String? _frequency(TransitStationLine line, String service) {
    if (line.frequency[service] case (final min, final max)) {
      return min == max ? '$min min' : '$min-$max min';
    }
    return null;
  }
}

/// Satu hari perkhidmatan sebagai lajur sejajar - hari, waktu, kekerapan.
///
/// Lajur dan bukan satu ayat bersambung: pengguna mengimbas ke bawah untuk
/// satu nilai (bilakah tren terakhir?), dan mengimbas hanya berfungsi bila
/// nilai itu berbaris.
class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.day,
    required this.hours,
    required this.frequency,
  });

  final String day;
  final String hours;
  final String? frequency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final numeric = style?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 108, child: Text(day, style: style)),
          Expanded(child: Text(hours, style: numeric)),
          if (frequency case final text?)
            Text(text, style: numeric, textAlign: TextAlign.end),
        ],
      ),
    );
  }
}

/// Warna datang dari feed, jadi ia boleh jadi apa sahaja. Cacat sintaks tak
/// patut menjatuhkan kad - jatuh balik ke warna tema.
Color parseTransitColor(String? hex, Color fallback) {
  if (hex == null) return fallback;
  final value = hex.replaceFirst('#', '');
  if (value.length != 6) return fallback;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(0xff000000 | parsed);
}

/// Warna laluan Rapid KL merangkumi kuning cerah (Putrajaya `#FFCD00`) dan
/// merah gelap (Sri Petaling `#76232f`), jadi teks putih tetap akan hilang
/// pada sebahagiannya.
Color transitOnColor(Color background) =>
    background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
