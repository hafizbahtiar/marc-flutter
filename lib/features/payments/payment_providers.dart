import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marc/core/api_client.dart';
import 'package:marc/core/auth_state.dart';
import 'package:marc/core/error_utils.dart';
import 'package:marc/features/payments/payment_models.dart';
import 'package:marc/features/profile/profile_providers.dart';

/// Sejarah bayaran SENDIRI (`GET /me/payments`) - yuran pendaftaran +
/// yuran aktiviti + derma. Set kecil per ahli (bukan log peristiwa yang
/// bertambah tanpa had), jadi tiada pagination di sini - beza drpd
/// `paymentLogsProvider` di bawah.
final myPaymentHistoryProvider = FutureProvider<MyPaymentHistory>((ref) async {
  final isLoggedIn = ref.watch(
    authNotifierProvider.select((s) => s.isLoggedIn),
  );
  if (!isLoggedIn) {
    return const MyPaymentHistory(
      registrationFee: [],
      activityFees: [],
      donations: [],
    );
  }

  final res = await ref.watch(dioProvider).get('/me/payments');
  return MyPaymentHistory.fromJson(res.data as Map<String, dynamic>);
});

const _pageSize = 50;

/// Penapis skrin "Semua Bayaran" (pengurusan). Sebahagian daripada kunci
/// provider - tukar penapis bina semula notifier & muat semula dari mula
/// (padanan AuditFilter/auditLogsProvider).
class PaymentLogFilter {
  const PaymentLogFilter({this.module});

  /// null = semua modul.
  final String? module;

  PaymentLogFilter copyWith({Object? module = _sentinel}) {
    return PaymentLogFilter(
      module: module == _sentinel ? this.module : module as String?,
    );
  }

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      other is PaymentLogFilter && other.module == module;

  @override
  int get hashCode => module.hashCode;
}

class PaymentLogState {
  const PaymentLogState({
    this.logs = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<PaymentLogEntry> logs;
  final bool hasMore;
  final bool isLoadingMore;

  PaymentLogState copyWith({
    List<PaymentLogEntry>? logs,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return PaymentLogState(
      logs: logs ?? this.logs,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Tinjauan bayaran merentas modul untuk pengurusan (`GET /admin/payments`)
/// - pagination keyset `before_id`, padanan corak `AuditLogNotifier`.
class PaymentLogNotifier
    extends FamilyAsyncNotifier<PaymentLogState, PaymentLogFilter> {
  @override
  Future<PaymentLogState> build(PaymentLogFilter arg) async {
    // Reaktif pada status log masuk DAN kebenaran management - provider ni
    // BUKAN autoDispose (konvensyen repo), jadi tanpa watch di sini jejak
    // bayaran yang dah dimuat kekal dalam memori selepas logout/downgrade
    // role. Data kewangan merentas SEMUA ahli - kena ikut guard sekeras
    // audit logs.
    final isLoggedIn = ref.watch(
      authNotifierProvider.select((s) => s.isLoggedIn),
    );
    final isManagement = ref.watch(
      myProfileProvider.select((p) => p.valueOrNull?.isManagement ?? false),
    );
    if (!isLoggedIn || !isManagement) {
      return const PaymentLogState(hasMore: false);
    }

    final logs = await _fetch(beforeId: null);
    return PaymentLogState(logs: logs, hasMore: logs.length == _pageSize);
  }

  Future<List<PaymentLogEntry>> _fetch({required int? beforeId}) async {
    final res = await ref
        .read(dioProvider)
        .get(
          '/admin/payments',
          queryParameters: {
            'limit': _pageSize,
            'before_id': ?beforeId,
            'module': ?arg.module,
          },
        );
    final data = res.data as Map<String, dynamic>;
    return (data['logs'] as List)
        .map((e) => PaymentLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        current.logs.isEmpty) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _fetch(beforeId: current.logs.last.id);
      final latest = state.valueOrNull ?? current;
      state = AsyncData(
        latest.copyWith(
          logs: [...latest.logs, ...next],
          hasMore: next.length == _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      final latest = state.valueOrNull ?? current;
      state = AsyncData(latest.copyWith(isLoadingMore: false));
    }
  }
}

final paymentLogsProvider =
    AsyncNotifierProvider.family<
      PaymentLogNotifier,
      PaymentLogState,
      PaymentLogFilter
    >(PaymentLogNotifier.new);

/// Hasil meminta pautan muat turun resit.
///
/// `url` bukan null = berjaya; jika tidak `message` ialah sebab yang
/// boleh terus dipapar. Padanan `CertificateLinkResult`
/// (`activity_providers.dart`).
class ReceiptLinkResult {
  const ReceiptLinkResult.ok(String this.url) : message = null;
  const ReceiptLinkResult.failed(String this.message) : url = null;

  final String? url;
  final String? message;

  bool get isOk => url != null;
}

/// 409 daripada endpoint resit bukan kegagalan - bayaran tu sendiri
/// masih 'pending'/'failed', backend tolak jana resit sengaja (tiada apa
/// nak diresitkan lagi).
const receiptNotReadyMessage = 'Bayaran belum berjaya, resit belum tersedia.';

final paymentReceiptRepositoryProvider = Provider<PaymentReceiptRepository>(
  (ref) => PaymentReceiptRepository(ref),
);

/// Minta URL bertandatangan bagi PDF resit - endpoint pulangkan
/// `{"url": "..."}` (R2 yang sampaikan fail, bukan bait terus), padanan
/// corak `CertificateRepository.fileUrl`. Pemanggil membuka URL dengan
/// `url_launcher`; tiada apa-apa ditulis ke storan peranti.
class PaymentReceiptRepository {
  PaymentReceiptRepository(this._ref);
  final Ref _ref;

  Future<ReceiptLinkResult> registrationFee(String paymentId) =>
      _fetch('/me/payments/registration/$paymentId/receipt');

  Future<ReceiptLinkResult> activityFee(String registrationId) =>
      _fetch('/me/payments/activity/$registrationId/receipt');

  Future<ReceiptLinkResult> donation(String donationId) =>
      _fetch('/me/payments/donation/$donationId/receipt');

  Future<ReceiptLinkResult> _fetch(String path) async {
    try {
      final res = await _ref.read(dioProvider).get(path);
      final data = res.data;
      final url = data is Map ? data['url'] : null;
      if (url is! String || url.isEmpty) {
        return const ReceiptLinkResult.failed('Gagal muat turun resit.');
      }
      return ReceiptLinkResult.ok(url);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        return const ReceiptLinkResult.failed(receiptNotReadyMessage);
      }
      return ReceiptLinkResult.failed(extractErrorMessage(e));
    } catch (_) {
      return const ReceiptLinkResult.failed('Gagal muat turun resit.');
    }
  }
}
