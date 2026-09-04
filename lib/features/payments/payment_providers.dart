import 'dart:convert';
import 'dart:typed_data';

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

/// Hasil meminta bait PDF resit.
///
/// `bytes` bukan null = berjaya; jika tidak `message` ialah sebab yang
/// boleh terus dipapar.
///
/// Sebelum 2026-08-24 ni `ReceiptLinkResult` (bawa URL R2
/// bertandatangan) - backend kini stream PDF TERUS (tiada simpanan R2
/// langsung untuk resit lagi, lihat catatan di repo backend), jadi
/// client terima bait terus dan buka dengan `printing` (bukan
/// `launchUrl` pada URL luaran lagi).
class ReceiptBytesResult {
  const ReceiptBytesResult.ok(this.bytes, {this.filename}) : message = null;
  const ReceiptBytesResult.failed(String this.message)
    : bytes = null,
      filename = null;

  final Uint8List? bytes;

  /// Nama fail SEBENAR dari backend (header `Content-Disposition`,
  /// cth `Resit-Pendaftaran-MARC-TBP123456789.pdf`) - `null` kalau
  /// header tiada/tak dapat dihurai, caller patut jatuh balik ke nama
  /// generik.
  final String? filename;
  final String? message;

  bool get isOk => bytes != null;
}

/// Hurai nama fail daripada header `Content-Disposition:
/// attachment; filename="...".pdf` - `null` kalau header tiada/format
/// tak dijangka. Backend (`payments.go` `respondReceiptPDF`) sentiasa
/// hantar dalam bentuk ni, tapi jangan crash kalau proksi/CDN kelak
/// ubah suai header dalam laluan.
String? _parseContentDispositionFilename(Headers headers) {
  final raw = headers.value('content-disposition');
  if (raw == null) return null;
  final match = RegExp(r'filename="?([^";]+)"?').firstMatch(raw);
  return match?.group(1);
}

/// 409 daripada endpoint resit bukan kegagalan - bayaran tu sendiri
/// masih 'pending'/'failed', backend tolak jana resit sengaja (tiada apa
/// nak diresitkan lagi).
const receiptNotReadyMessage = 'Bayaran belum berjaya, resit belum tersedia.';

final paymentReceiptRepositoryProvider = Provider<PaymentReceiptRepository>(
  (ref) => PaymentReceiptRepository(ref),
);

/// Minta bait PDF resit TERUS daripada backend - `responseType: bytes`
/// sebab endpoint kini pulangkan `application/pdf` mentah (bukan
/// `{"url": "..."}` lagi). Pemanggil buka bait guna `printing`
/// (`Printing.layoutPdf`, dialog preview/simpan/kongsi/cetak native).
class PaymentReceiptRepository {
  PaymentReceiptRepository(this._ref);
  final Ref _ref;

  Future<ReceiptBytesResult> registrationFee(String paymentId) =>
      _fetch('/me/payments/registration/$paymentId/receipt');

  Future<ReceiptBytesResult> activityFee(String registrationId) =>
      _fetch('/me/payments/activity/$registrationId/receipt');

  Future<ReceiptBytesResult> donation(String donationId) =>
      _fetch('/me/payments/donation/$donationId/receipt');

  Future<ReceiptBytesResult> _fetch(String path) async {
    try {
      final res = await _ref
          .read(dioProvider)
          .get<List<int>>(
            path,
            options: Options(responseType: ResponseType.bytes),
          );
      final data = res.data;
      if (data == null || data.isEmpty) {
        return const ReceiptBytesResult.failed('Gagal muat turun resit.');
      }
      return ReceiptBytesResult.ok(
        Uint8List.fromList(data),
        filename: _parseContentDispositionFilename(res.headers),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        return const ReceiptBytesResult.failed(receiptNotReadyMessage);
      }
      return ReceiptBytesResult.failed(_extractBytesError(e));
    } catch (_) {
      return const ReceiptBytesResult.failed('Gagal muat turun resit.');
    }
  }
}

/// `extractErrorMessage` andaikan `e.response?.data` sudah nyahsiri
/// (Map) - betul untuk permintaan JSON biasa, tapi request resit ni
/// paksa `responseType: bytes` (perlu terima PDF mentah bila BERJAYA),
/// jadi badan ralat pun sampai sebagai `List<int>` mentah, bukan Map.
/// Cuba nyahsiri sendiri dahulu (badan ralat backend Go kecil, selamat
/// dibaca penuh) sebelum jatuh balik ke `extractErrorMessage` (yang
/// tetap betul untuk status-code generik/timeout/dsb - cuma tak dapat
/// mesej Melayu spesifik daripada JSON dalam kes ni).
String _extractBytesError(DioException e) {
  final data = e.response?.data;
  if (data is List<int>) {
    try {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // Badan bukan JSON sah - jatuh balik ke bawah.
    }
  }
  return extractErrorMessage(e);
}
