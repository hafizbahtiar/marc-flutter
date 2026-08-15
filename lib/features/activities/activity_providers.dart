import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/activities/activity_models.dart';
import 'package:marc/features/registration_payment/registration_payment_providers.dart'
    show PhoneRequiredException;

/// Penapis senarai aktiviti. `categoryId` null = semua kategori.
class ActivityFilter {
  const ActivityFilter({
    this.upcoming = true,
    this.categoryId,
    this.drafts = false,
  });

  final bool upcoming;
  final String? categoryId;

  /// Papar DRAF sahaja. Backend meninggalkan draf keluar daripada senarai
  /// lalai dan menuntut role pengurusan untuk `status=draft` — tanpa
  /// penapis ini, aktiviti yang baru dicipta tidak boleh dijumpai semula
  /// dalam app untuk diterbitkan.
  final bool drafts;

  ActivityFilter copyWith({
    bool? upcoming,
    String? Function()? categoryId,
    bool? drafts,
  }) => ActivityFilter(
    upcoming: upcoming ?? this.upcoming,
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    drafts: drafts ?? this.drafts,
  );

  @override
  bool operator ==(Object other) =>
      other is ActivityFilter &&
      other.upcoming == upcoming &&
      other.categoryId == categoryId &&
      other.drafts == drafts;

  @override
  int get hashCode => Object.hash(upcoming, categoryId, drafts);
}

final activityFilterProvider = StateProvider<ActivityFilter>(
  (ref) => const ActivityFilter(),
);

/// State senarai: aktiviti + cursor untuk load-more. Sama bentuk dengan
/// `FeedState` — backend guna keyset pagination yang sama.
class ActivitiesState {
  const ActivitiesState({
    this.activities = const [],
    this.nextCursor,
    this.isLoadingMore = false,
  });

  final List<Activity> activities;
  final String? nextCursor;
  final bool isLoadingMore;

  bool get hasMore => nextCursor != null;

  ActivitiesState copyWith({
    List<Activity>? activities,
    String? Function()? nextCursor,
    bool? isLoadingMore,
  }) => ActivitiesState(
    activities: activities ?? this.activities,
    nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

class ActivitiesNotifier extends AsyncNotifier<ActivitiesState> {
  /// Penjaga generasi — sama rasional dengan `FeedNotifier`: halaman yang
  /// tiba lewat selepas penapis bertukar tidak boleh menulis ke atas
  /// senarai yang lebih baharu.
  int _generation = 0;

  @override
  Future<ActivitiesState> build() async {
    _generation++;
    final isLoggedIn = ref.watch(
      authNotifierProvider.select((s) => s.isLoggedIn),
    );
    if (!isLoggedIn) return const ActivitiesState();

    // Tukar tab "Akan Datang"/"Lepas" atau cip kategori → muat semula
    // dari halaman pertama. Cursor lama milik penapis lama.
    ref.watch(activityFilterProvider);
    return _fetchPage(cursor: null);
  }

  Future<ActivitiesState> _fetchPage({required String? cursor}) async {
    final filter = ref.read(activityFilterProvider);
    final res = await ref
        .read(dioProvider)
        .get(
          '/activities',
          queryParameters: {
            'upcoming': filter.upcoming.toString(),
            'category_id': ?filter.categoryId,
            'status': ?(filter.drafts ? 'draft' : null),
            'cursor': ?cursor,
          },
        );
    final data = res.data as Map<String, dynamic>;
    final activities = (data['activities'] as List)
        .map((a) => Activity.fromJson(a as Map<String, dynamic>))
        .toList();
    return ActivitiesState(
      activities: activities,
      nextCursor: data['next_cursor'] as String?,
    );
  }

  Future<void> refresh() async {
    final gen = ++_generation;
    state = AsyncLoading<ActivitiesState>().copyWithPrevious(state);
    final result = await AsyncValue.guard(() => _fetchPage(cursor: null));
    if (gen != _generation) return;
    state = result;
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    final gen = _generation;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _fetchPage(cursor: current.nextCursor);
      if (gen != _generation) return;
      final latest = state.valueOrNull ?? current;
      state = AsyncData(
        latest.copyWith(
          activities: [...latest.activities, ...next.activities],
          nextCursor: () => next.nextCursor,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      if (gen != _generation) return;
      final latest = state.valueOrNull ?? current;
      state = AsyncData(latest.copyWith(isLoadingMore: false));
    }
  }

  /// Tindih satu aktiviti dalam senarai — dipanggil selepas daftar/batal
  /// dari halaman detail supaya kiraan slot dalam senarai sync balik
  /// tanpa pull-to-refresh manual.
  void patch(Activity updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        activities: current.activities
            .map((a) => a.id == updated.id ? updated : a)
            .toList(),
      ),
    );
  }

  /// Kemas kini optimistik kiraan+status pendaftaran bagi satu aktiviti
  /// dalam senarai. Pulangkan versi SEBELUM ubah supaya pemanggil boleh
  /// menggulungnya semula bila server menolak.
  Activity? applyRegistration(String activityId, {required bool registered}) {
    final current = state.valueOrNull;
    if (current == null) return null;
    final index = current.activities.indexWhere((a) => a.id == activityId);
    if (index == -1) return null;

    final before = current.activities[index];
    if (before.isRegistered == registered) return before;

    final after = before.copyWith(
      isRegistered: registered,
      registrationCount: before.registrationCount + (registered ? 1 : -1),
    );
    patch(after);
    return before;
  }
}

final activitiesProvider =
    AsyncNotifierProvider<ActivitiesNotifier, ActivitiesState>(
      ActivitiesNotifier.new,
    );

/// Kategori untuk cip penapis. Jarang berubah — dibiarkan cache seumur
/// hayat ProviderContainer.
final activityCategoriesProvider = FutureProvider<List<ActivityCategory>>((
  ref,
) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) return const [];

  final res = await ref.watch(dioProvider).get('/activity-categories');
  final data = res.data as Map<String, dynamic>;
  return (data['categories'] as List)
      .map((c) => ActivityCategory.fromJson(c as Map<String, dynamic>))
      .toList();
});

/// Aktiviti tunggal (halaman detail). Sama rasional dengan
/// `postDetailProvider` — throw bila logout supaya halaman papar error
/// state dan bukan cache aktiviti user lama pada peranti yang sama.
final activityDetailProvider = FutureProvider.family<Activity, String>((
  ref,
  activityId,
) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) {
    throw StateError('Sesi tamat — sila log masuk semula.');
  }

  final res = await ref.watch(dioProvider).get('/activities/$activityId');
  return Activity.fromJson(res.data as Map<String, dynamic>);
});

/// Pendaftaran aktif pemanggil — `GET /me/activities`.
final myRegistrationsProvider = FutureProvider<List<MyRegistration>>((
  ref,
) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) return const [];

  final res = await ref.watch(dioProvider).get('/me/activities');
  final data = res.data as Map<String, dynamic>;
  return (data['registrations'] as List)
      .map((r) => MyRegistration.fromJson(r as Map<String, dynamic>))
      .toList();
});

/// Sijil pemanggil — `GET /me/certificates`. Sijil yang ditarik balik
/// tidak dipulangkan oleh backend, jadi tiada penapisan di sini.
final myCertificatesProvider = FutureProvider<List<MyCertificate>>((ref) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) return const [];

  final res = await ref.watch(dioProvider).get('/me/certificates');
  final data = res.data as Map<String, dynamic>;
  return (data['certificates'] as List)
      .map((c) => MyCertificate.fromJson(c as Map<String, dynamic>))
      .toList();
});

/// Hasil meminta pautan muat turun sijil.
///
/// `url` bukan null = berjaya; jika tidak `message` ialah sebab yang
/// boleh terus dipapar.
class CertificateLinkResult {
  const CertificateLinkResult.ok(String this.url) : message = null;
  const CertificateLinkResult.failed(String this.message) : url = null;

  final String? url;
  final String? message;

  bool get isOk => url != null;
}

/// 409 daripada `/me/certificates/:id/file` bukan kegagalan.
///
/// Backend menerbitkan sijil dalam DUA fasa: baris + nombor siri komit
/// dahulu, PDF dijana dan dimuat naik selepasnya. Antara kedua-duanya
/// sijil itu WUJUD dan sah — cuma failnya belum ada. Mesej ralat generik
/// di sini akan menyuruh ahli melaporkan pepijat untuk keadaan yang
/// selesai sendiri dalam beberapa saat.
const certificatePendingMessage =
    'Sijil sedang disediakan. Cuba lagi sebentar.';

final certificateRepositoryProvider = Provider<CertificateRepository>(
  (ref) => CertificateRepository(ref),
);

class CertificateRepository {
  CertificateRepository(this._ref);
  final Ref _ref;

  /// Minta URL bertandatangan bagi PDF sijil.
  ///
  /// Endpoint memulangkan `{"url": "..."}` dan BUKAN bait — R2 yang
  /// menyampaikan fail. Pemanggil membuka URL itu dengan `url_launcher`;
  /// tiada apa-apa yang ditulis ke storan peranti.
  Future<CertificateLinkResult> fileUrl(String certificateId) async {
    try {
      final res = await _ref
          .read(dioProvider)
          .get('/me/certificates/$certificateId/file');
      final data = res.data;
      final url = data is Map ? data['url'] : null;
      if (url is! String || url.isEmpty) {
        return const CertificateLinkResult.failed('Gagal buka sijil.');
      }
      return CertificateLinkResult.ok(url);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 409) {
        return const CertificateLinkResult.failed(certificatePendingMessage);
      }
      if (code == 410) {
        // Ditarik balik selepas senarai ini dimuatkan. Baris itu tidak
        // sepatutnya kekal dipapar — senarai dibaca semula supaya ia
        // hilang, bukan sekadar gagal setiap kali diketuk.
        _ref.invalidate(myCertificatesProvider);
      }
      return CertificateLinkResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const CertificateLinkResult.failed('Gagal buka sijil.');
    }
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref),
);

/// Hasil satu percubaan daftar/batal.
///
/// `message` bukan null bermakna GAGAL dengan sebab yang boleh dibaca —
/// termasuk 409, yang bukan kes tepi tetapi jawapan biasa daripada
/// server.
class RegistrationResult {
  const RegistrationResult.ok() : message = null;
  const RegistrationResult.failed(this.message);

  final String? message;

  bool get isOk => message == null;
}

class ActivityRepository {
  ActivityRepository(this._ref);
  final Ref _ref;

  /// Daftar aktiviti, dengan kiraan dikemas kini secara optimistik.
  ///
  /// 409 daripada server ialah KEBENARAN, bukan kes tepi: dua ahli boleh
  /// menekan Daftar dalam saat yang sama dan kiraan tempatan tak dapat
  /// menghalangnya — server yang menyerikan lewat kunci baris. Bila ia
  /// menolak, kemas kini optimistik digulung semula DAN detail
  /// di-invalidate supaya kiraan sebenar (yang mungkin sudah bergerak
  /// kerana orang lain) dibaca semula dari server, bukan diteka.
  Future<RegistrationResult> register(String activityId) =>
      _mutate(activityId, registered: true);

  Future<RegistrationResult> cancel(String activityId) =>
      _mutate(activityId, registered: false);

  Future<RegistrationResult> _mutate(
    String activityId, {
    required bool registered,
  }) async {
    final notifier = _ref.read(activitiesProvider.notifier);
    final before = notifier.applyRegistration(
      activityId,
      registered: registered,
    );

    try {
      final dio = _ref.read(dioProvider);
      if (registered) {
        await dio.post('/activities/$activityId/registration');
      } else {
        await dio.delete('/activities/$activityId/registration');
      }
      // Baca semula kiraan sebenar — pendaftaran orang lain yang mendarat
      // antara muatan terakhir dan ketukan ini hanya kelihatan di server.
      _ref.invalidate(activityDetailProvider(activityId));
      _ref.invalidate(myRegistrationsProvider);
      await _syncToList(activityId);
      return const RegistrationResult.ok();
    } on DioException catch (e) {
      if (before != null) notifier.patch(before);
      _ref.invalidate(activityDetailProvider(activityId));
      // 409 (penuh / pendaftaran ditutup / sudah berdaftar / belum
      // dibuka), 403 (bukan pengurusan), 400 (parameter buruk) — semuanya
      // datang dengan `{"error": "..."}` Bahasa Melayu dari backend, jadi
      // mesejnya boleh terus dipapar.
      return RegistrationResult.failed(extractErrorMessage(e));
    } catch (_) {
      if (before != null) notifier.patch(before);
      _ref.invalidate(activityDetailProvider(activityId));
      return RegistrationResult.failed(
        registered ? 'Gagal daftar aktiviti.' : 'Gagal batal pendaftaran.',
      );
    }
  }

  /// Mulakan pembayaran yuran AKTIVITI (bukan yuran pendaftaran ahli —
  /// itu `RegistrationPaymentRepository.checkout`) untuk pendaftaran yang
  /// SUDAH wujud. [phone] pilihan, sama pola dengan
  /// `RegistrationPaymentRepository.checkout`: hanya perlu bila
  /// percubaan pertama melempar [PhoneRequiredException]. Pulangkan
  /// `redirect_url` sahaja.
  Future<String> checkoutPayment(String activityId, {String? phone}) async {
    final dio = _ref.read(dioProvider);
    try {
      final res = await dio.post(
        '/activities/$activityId/registration/checkout',
        data: phone != null ? {'phone': phone} : null,
      );
      return res.data['redirect_url'] as String;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['code'] == 'phone_required') {
        throw PhoneRequiredException();
      }
      rethrow;
    }
  }

  /// Tarik versi terkini dari server dan tindih ke dalam senarai — best
  /// effort, tak boleh gagalkan mutasi yang dah pun berjaya.
  Future<void> _syncToList(String activityId) async {
    try {
      final updated = await _ref.read(
        activityDetailProvider(activityId).future,
      );
      _ref.read(activitiesProvider.notifier).patch(updated);
    } catch (_) {
      // Senarai cuma tak sync sehingga refresh seterusnya.
    }
  }
}
