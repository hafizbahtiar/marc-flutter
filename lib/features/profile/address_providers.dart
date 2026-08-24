import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';

/// Senarai negeri/wilayah Malaysia (16) - guna dalam dropdown borang
/// alamat. Const list, bukan dari backend - senarai ni tak berubah.
const kMalaysianStates = <String>[
  'Johor',
  'Kedah',
  'Kelantan',
  'Melaka',
  'Negeri Sembilan',
  'Pahang',
  'Perak',
  'Perlis',
  'Pulau Pinang',
  'Sabah',
  'Sarawak',
  'Selangor',
  'Terengganu',
  'Wilayah Persekutuan Kuala Lumpur',
  'Wilayah Persekutuan Labuan',
  'Wilayah Persekutuan Putrajaya',
];

/// Had bilangan alamat setiap ahli - padanan `member_addresses` app-layer
/// limit di backend (bukan constraint DB, lihat spec).
const kMaxAddresses = 3;

class AddressRow {
  const AddressRow({
    required this.id,
    this.label,
    required this.isDefault,
    required this.addressType,
    this.unitNumber,
    this.floor,
    this.block,
    this.street,
    this.township,
    required this.city,
    required this.postcode,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? label;
  final bool isDefault;

  /// "landed" atau "highrise".
  final String addressType;
  final String? unitNumber;

  /// Tingkat - cuma relevan bila [addressType] == "highrise".
  final String? floor;

  /// Blok - cuma relevan bila [addressType] == "highrise".
  final String? block;
  final String? street;
  final String? township;
  final String city;
  final String postcode;
  final String state;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isHighrise => addressType == 'highrise';

  /// Alamat penuh dikira dari medan berstruktur - TAK disimpan sbg lajur
  /// berasingan (padanan keputusan reka bentuk spec, elak dua sumber
  /// kebenaran).
  String get summary {
    final parts = <String>[
      if (isHighrise) ...[
        if (unitNumber != null && unitNumber!.isNotEmpty)
          'Unit $unitNumber',
        if (floor != null && floor!.isNotEmpty) 'Tingkat $floor',
        if (block != null && block!.isNotEmpty) 'Blok $block',
      ] else ...[
        if (unitNumber != null && unitNumber!.isNotEmpty) unitNumber!,
      ],
      if (street != null && street!.isNotEmpty) street!,
      if (township != null && township!.isNotEmpty) township!,
    ];
    return parts.join(', ');
  }

  String get cityLine => '$postcode $city, $state';

  factory AddressRow.fromJson(Map<String, dynamic> json) {
    return AddressRow(
      id: json['id'] as String,
      label: json['label'] as String?,
      isDefault: (json['is_default'] as bool?) ?? false,
      addressType: (json['address_type'] as String?) ?? 'landed',
      unitNumber: json['unit_number'] as String?,
      floor: json['floor'] as String?,
      block: json['block'] as String?,
      street: json['street'] as String?,
      township: json['township'] as String?,
      city: (json['city'] as String?) ?? '',
      postcode: (json['postcode'] as String?) ?? '',
      state: (json['state'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Senarai alamat ahli semasa.
final addressesProvider = FutureProvider<List<AddressRow>>((ref) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) return const [];

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/me/addresses');
  return (res.data as List)
      .map((a) => AddressRow.fromJson(a as Map<String, dynamic>))
      .toList();
});

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => AddressRepository(ref),
);

class AddressRepository {
  AddressRepository(this._ref);
  final Ref _ref;

  /// Tambah alamat baharu. Backend paksa `is_default=true` utk alamat
  /// PERTAMA ahli tanpa kira [isDefault] dihantar (lihat spec).
  Future<void> create({
    String? label,
    required String addressType,
    String? unitNumber,
    String? floor,
    String? block,
    String? street,
    String? township,
    required String city,
    required String postcode,
    required String state,
    bool isDefault = false,
  }) async {
    final dio = _ref.read(dioProvider);
    await dio.post(
      '/me/addresses',
      data: {
        'label': ?label,
        'address_type': addressType,
        'unit_number': ?unitNumber,
        'floor': ?floor,
        'block': ?block,
        'street': ?street,
        'township': ?township,
        'city': city,
        'postcode': postcode,
        'state': state,
        'is_default': isDefault,
      },
    );
    _ref.invalidate(addressesProvider);
  }

  /// Kemas kini alamat sedia ada - semua medan opsyenal (partial update,
  /// padanan `PATCH /me`). `isDefault: true` nyahtetapkan default lama di
  /// backend dalam transaksi yang sama.
  Future<void> update(
    String id, {
    String? label,
    String? addressType,
    String? unitNumber,
    String? floor,
    String? block,
    String? street,
    String? township,
    String? city,
    String? postcode,
    String? state,
    bool? isDefault,
  }) async {
    final dio = _ref.read(dioProvider);
    await dio.patch(
      '/me/addresses/$id',
      data: {
        'label': ?label,
        'address_type': ?addressType,
        'unit_number': ?unitNumber,
        'floor': ?floor,
        'block': ?block,
        'street': ?street,
        'township': ?township,
        'city': ?city,
        'postcode': ?postcode,
        'state': ?state,
        'is_default': ?isDefault,
      },
    );
    _ref.invalidate(addressesProvider);
  }

  /// Padam alamat. Kalau baris ni default DAN ada baris lain tinggal,
  /// backend auto-promote baris paling lama jadi default baharu.
  Future<void> delete(String id) async {
    final dio = _ref.read(dioProvider);
    await dio.delete('/me/addresses/$id');
    _ref.invalidate(addressesProvider);
  }
}
