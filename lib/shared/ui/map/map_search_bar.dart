import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:marc/shared/ui/map/app_map.dart';
import 'package:marc/shared/ui/map/place_search.dart';

/// Keadaan satu carian: menaip, memuatkan, hasil, atau ralat.
///
/// Satu jenis untuk keempat-empatnya supaya UI mustahil memaparkan dua
/// keadaan serentak - cth spinner di atas senarai lama.
sealed class MapSearchState {
  const MapSearchState();
}

class MapSearchIdle extends MapSearchState {
  const MapSearchIdle();
}

class MapSearchLoading extends MapSearchState {
  const MapSearchLoading();
}

class MapSearchResults extends MapSearchState {
  const MapSearchResults(this.results);

  final List<PlaceResult> results;
}

class MapSearchFailed extends MapSearchState {
  const MapSearchFailed(this.message);

  final String message;
}

/// Menyahlantun taipan, membatalkan permintaan lama, dan menyiarkan satu
/// keadaan.
///
/// Berasingan daripada widget supaya nyahlantun dan pembatalan boleh diuji
/// tanpa memompa bingkai.
class MapSearchController extends ValueNotifier<MapSearchState> {
  MapSearchController({
    PlaceSearchService? service,
    this.debounce = kPlaceSearchDebounce,
  }) : _service = service ?? PlaceSearchService(),
       super(const MapSearchIdle());

  final PlaceSearchService _service;
  final Duration debounce;

  Timer? _timer;
  CancelToken? _inFlight;

  /// Bertambah setiap pertanyaan. Jawapan yang tiba selepas pertanyaan
  /// lebih baru dibuang - tanpa ni, respons perlahan untuk "kl" boleh
  /// menimpa hasil untuk "klcc" yang pengguna sedang lihat.
  int _generation = 0;

  void query(String text, {LatLng? near}) {
    _timer?.cancel();
    _inFlight?.cancel();
    _inFlight = null;

    final trimmed = text.trim();
    if (trimmed.length < kPlaceSearchMinChars) {
      _generation++;
      value = const MapSearchIdle();
      return;
    }

    _timer = Timer(debounce, () => unawaited(_run(trimmed, near)));
  }

  Future<void> _run(String text, LatLng? near) async {
    final generation = ++_generation;
    final cancelToken = CancelToken();
    _inFlight = cancelToken;
    value = const MapSearchLoading();

    try {
      final results = await _service.search(
        text,
        near: near,
        cancelToken: cancelToken,
      );
      if (generation != _generation) return;
      value = MapSearchResults(results);
    } on PlaceSearchException catch (error) {
      if (generation != _generation) return;
      value = MapSearchFailed(error.message);
    }
  }

  void clear() {
    _timer?.cancel();
    _inFlight?.cancel();
    _inFlight = null;
    _generation++;
    value = const MapSearchIdle();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inFlight?.cancel();
    super.dispose();
  }
}

/// Pil carian terapung dengan senarai hasil di bawahnya.
class MapSearchBar extends StatelessWidget {
  const MapSearchBar({
    super.key,
    required this.controller,
    required this.textController,
    required this.onQueryChanged,
    required this.onSelected,
    required this.onClear,
  });

  final MapSearchController controller;
  final TextEditingController textController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<PlaceResult> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchField(
          textController: textController,
          onQueryChanged: onQueryChanged,
          onClear: onClear,
        ),
        ValueListenableBuilder<MapSearchState>(
          valueListenable: controller,
          builder: (context, state, _) => switch (state) {
            MapSearchIdle() => const SizedBox.shrink(),
            MapSearchLoading() => _Panel(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              ),
            ),
            MapSearchFailed(:final message) => _Panel(
              child: _Message(text: message, icon: Icons.cloud_off_outlined),
            ),
            MapSearchResults(:final results) when results.isEmpty => _Panel(
              child: _Message(
                text: 'Tiada tempat ditemui.',
                icon: Icons.search_off_outlined,
              ),
            ),
            MapSearchResults(:final results) => _Panel(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final result = results[i];
                  return ListTile(
                    leading: Icon(_iconFor(result), color: scheme.primary),
                    title: Text(
                      result.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: result.subtitle == null
                        ? null
                        : Text(
                            result.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () => onSelected(result),
                  );
                },
              ),
            ),
          },
        ),
      ],
    );
  }

  /// Padan `osm_key` DAN `osm_value`. Nilai sahaja tak cukup - `station`
  /// bermakna lain di bawah `railway` berbanding `aeroway`, dan versi
  /// pertama fungsi ni memadankan `mosque` yang tak pernah wujud: masjid
  /// ialah `amenity/place_of_worship` dalam OSM.
  static IconData _iconFor(PlaceResult result) {
    final value = result.kind;
    return switch (result.category) {
      'railway' || 'public_transport' => switch (value) {
        'bus_stop' || 'bus_station' => Icons.directions_bus_outlined,
        _ => Icons.train_outlined,
      },
      'highway' when value == 'bus_stop' => Icons.directions_bus_outlined,
      'aeroway' => Icons.flight_outlined,
      'leisure' => switch (value) {
        'park' || 'garden' || 'nature_reserve' => Icons.park_outlined,
        'pitch' || 'sports_centre' || 'stadium' => Icons.sports_soccer_outlined,
        'swimming_pool' => Icons.pool_outlined,
        _ => Icons.local_activity_outlined,
      },
      'shop' => switch (value) {
        'mall' || 'department_store' => Icons.local_mall_outlined,
        'supermarket' || 'convenience' => Icons.shopping_cart_outlined,
        _ => Icons.storefront_outlined,
      },
      'tourism' => switch (value) {
        'hotel' || 'motel' || 'hostel' || 'guest_house' => Icons.hotel_outlined,
        'museum' || 'gallery' => Icons.museum_outlined,
        'zoo' || 'attraction' || 'theme_park' => Icons.attractions_outlined,
        _ => Icons.photo_camera_outlined,
      },
      'amenity' => switch (value) {
        'place_of_worship' => Icons.mosque_outlined,
        'restaurant' ||
        'fast_food' ||
        'food_court' => Icons.restaurant_outlined,
        'cafe' => Icons.local_cafe_outlined,
        'hospital' || 'clinic' || 'doctors' => Icons.local_hospital_outlined,
        'pharmacy' => Icons.local_pharmacy_outlined,
        'school' ||
        'university' ||
        'college' ||
        'kindergarten' => Icons.school_outlined,
        'bank' || 'atm' => Icons.account_balance_outlined,
        'marketplace' => Icons.storefront_outlined,
        'parking' => Icons.local_parking_outlined,
        'fuel' => Icons.local_gas_station_outlined,
        'police' => Icons.local_police_outlined,
        'toilets' => Icons.wc_outlined,
        'library' => Icons.local_library_outlined,
        _ => Icons.place_outlined,
      },
      'place' => Icons.location_city_outlined,
      'building' => Icons.apartment_outlined,
      'landuse' || 'boundary' => Icons.map_outlined,
      'office' => Icons.business_outlined,
      'healthcare' => Icons.local_hospital_outlined,
      _ => Icons.place_outlined,
    };
  }
}

/// Kotak carian terapung.
///
/// Setiap slot sempadan dikosongkan dan `filled` dimatikan dengan sengaja:
/// tema app menetapkan `focusedBorder` sebagai segi empat radius-12
/// berwarna primary, yang dilukis DI DALAM permukaan terapung ni dan
/// hujungnya terpotong oleh clipnya - menghasilkan lengkungan merah yang
/// tergantung di tepi. Permukaan ini yang memiliki bentuk, jadi ia juga
/// yang mesti memiliki keadaan fokus.
class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.textController,
    required this.onQueryChanged,
    required this.onClear,
  });

  final TextEditingController textController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus != _focused) {
        setState(() => _focused = _focus.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Radius 12 sepadan dengan MapControlGroup di sebelahnya dan token
    // seluruh app. Pil bulat penuh bersebelahan butang radius-12 ialah
    // sebab kroma peta nampak tak sepadan.
    const shape = BorderRadius.all(Radius.circular(12));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: shape,
        border: Border.all(
          color: _focused ? scheme.primary : scheme.outlineVariant,
          width: _focused ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: _focused ? 0.22 : 0.14),
            blurRadius: _focused ? 14 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: widget.textController,
        focusNode: _focus,
        onChanged: widget.onQueryChanged,
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Cari tempat',
          filled: false,
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          prefixIcon: Icon(
            Icons.search,
            size: 22,
            color: scheme.onSurfaceVariant,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 46),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.textController,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Kosongkan',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: widget.onClear,
                  ),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 40),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.surface,
        elevation: 3,
        shadowColor: scheme.shadow.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        // Hadkan tinggi supaya senarai tak pernah menutup peta sepenuhnya -
        // pengguna perlu nampak ke mana hasil itu akan membawa mereka.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.42,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
