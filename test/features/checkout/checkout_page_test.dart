import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/app/theme.dart';
import 'package:marc/features/checkout/checkout_page.dart';
import 'package:marc/features/checkout/checkout_providers.dart';
import 'package:marc/features/registration_payment/registration_payment_providers.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Palsukan `UrlLauncherPlatform.instance` - `extends` (bukan `implements`)
/// sebab konstruktor asal `super(token: _token)` yang membolehkan
/// `PlatformInterface.verify` lulus bila kita set `instance =` di bawah.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  String? lastUrl;
  LaunchOptions? lastOptions;
  bool shouldSucceed = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastUrl = url;
    lastOptions = options;
    return shouldSucceed;
  }
}

void main() {
  late _FakeUrlLauncher fakeLauncher;

  setUp(() {
    fakeLauncher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = fakeLauncher;
  });

  /// `MaterialApp` + skrin awal dengan butang "buka" yang push
  /// `CheckoutPage` - padan corak `test/shared/app_dialog_test.dart`.
  /// `platform: TargetPlatform.android` MEMASTIKAN dialog nombor
  /// telefon guna `TextField` Material (bukan `CupertinoTextField`).
  /// `paymentConfigProvider` di-override (bukan dibiar panggil
  /// `dioProvider` sebenar) - elak percubaan network sebenar dalam
  /// ujian, dan jadikan `gatewayChargeCents` deterministik.
  Widget host(CheckoutRequest request, {int gatewayChargeCents = 100}) {
    return ProviderScope(
      overrides: [
        paymentConfigProvider.overrideWith((ref) async => gatewayChargeCents),
      ],
      child: MaterialApp(
        theme: AppTheme.light.copyWith(platform: TargetPlatform.android),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CheckoutPage(request: request),
                  ),
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'papar breakdown invoice (yuran + caj gateway = jumlah) dan description',
    (tester) async {
      // `gatewayChargeCents: 250` (BUKAN 100/`kDefaultGatewayChargeCents`)
      // sengaja - nilai berbeza drpd fallback supaya ujian ni benar-benar
      // buktikan CheckoutPage guna nilai DIFETCH (provider override), bukan
      // sekadar fallback yang kebetulan sama (Opus verify 2026-08-24).
      await tester.pumpWidget(
        host(
          CheckoutRequest(
            title: 'Yuran Pendaftaran Ahli',
            amountCents: 1000, // RM10.00
            currency: 'myr',
            description: 'Sekali bayar',
            onCheckout: ({phone}) async => 'https://toyyibpay.com/abc',
          ),
          gatewayChargeCents: 250, // RM2.50
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.text('Yuran Pendaftaran Ahli'), findsWidgets); // AppBar
      expect(find.text('Sekali bayar'), findsOneWidget);
      expect(find.text('Yuran'), findsOneWidget);
      expect(find.text('MYR 7.50'), findsOneWidget);
      expect(find.text('Caj Pemprosesan Pembayaran'), findsOneWidget);
      expect(find.text('MYR 2.50'), findsOneWidget);
      expect(find.text('Jumlah Perlu Dibayar'), findsOneWidget);
      expect(find.text('MYR 10.00'), findsOneWidget);
    },
  );

  testWidgets(
    'jumlah <= caj gateway: papar "Jumlah Perlu Dibayar" sahaja, tiada breakdown',
    (tester) async {
      await tester.pumpWidget(
        host(
          CheckoutRequest(
            title: 'Yuran Aktiviti',
            amountCents: 100, // RM1.00 - sama dgn caj gateway
            currency: 'myr',
            onCheckout: ({phone}) async => 'https://toyyibpay.com/abc',
          ),
          gatewayChargeCents: 100,
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.text('Yuran'), findsNothing);
      expect(find.text('Caj Pemprosesan Pembayaran'), findsNothing);
      expect(find.text('Jumlah Perlu Dibayar'), findsOneWidget);
      expect(find.text('MYR 1.00'), findsOneWidget);
    },
  );

  testWidgets('checkout berjaya: buka URL lalu pop balik ke skrin asal', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        CheckoutRequest(
          title: 'Yuran Pendaftaran Ahli',
          amountCents: 1000,
          currency: 'myr',
          onCheckout: ({phone}) async => 'https://toyyibpay.com/abc',
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bayar Sekarang'));
    await tester.pumpAndSettle();

    expect(fakeLauncher.lastUrl, 'https://toyyibpay.com/abc');
    // `externalApplication`, bukan `platformDefault`/`inAppWebView` -
    // regresi mod pelancaran akan lulus test lain tanpa assertion ni
    // (Opus verify 2026-08-24).
    expect(
      fakeLauncher.lastOptions?.mode,
      PreferredLaunchMode.externalApplication,
    );
    // Balik ke skrin asal (butang "buka" nampak semula, CheckoutPage
    // dah di-pop).
    expect(find.text('buka'), findsOneWidget);
    expect(find.text('Bayar Sekarang'), findsNothing);
  });

  testWidgets('papar tanpa jumlah bila amountCents null (bukan "MYR 0.00")', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        CheckoutRequest(
          title: 'Yuran Aktiviti',
          amountCents: null,
          currency: 'myr',
          onCheckout: ({phone}) async => 'https://toyyibpay.com/abc',
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.textContaining('MYR'), findsNothing);
  });

  testWidgets('launchUrl pulang false - snackbar ralat, tak pop', (
    tester,
  ) async {
    fakeLauncher.shouldSucceed = false;
    await tester.pumpWidget(
      host(
        CheckoutRequest(
          title: 'X',
          amountCents: 500,
          currency: 'myr',
          onCheckout: ({phone}) async => 'https://toyyibpay.com/abc',
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bayar Sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('Gagal buka laman pembayaran.'), findsOneWidget);
    expect(find.text('Bayar Sekarang'), findsOneWidget); // tak pop
  });

  testWidgets('URL bukan https ditolak - snackbar ralat, tak pop', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        CheckoutRequest(
          title: 'X',
          amountCents: 500,
          currency: 'myr',
          onCheckout: ({phone}) async => 'http://insecure.example/abc',
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bayar Sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('Pautan pembayaran tidak sah.'), findsOneWidget);
    expect(fakeLauncher.lastUrl, isNull);
    // Masih dalam CheckoutPage (tak pop).
    expect(find.text('Bayar Sekarang'), findsOneWidget);
  });

  testWidgets(
    'PhoneRequiredException papar dialog nombor telefon, checkout semula',
    (tester) async {
      var callCount = 0;
      String? receivedPhone;
      await tester.pumpWidget(
        host(
          CheckoutRequest(
            title: 'X',
            amountCents: 500,
            currency: 'myr',
            onCheckout: ({phone}) async {
              callCount++;
              if (phone == null) throw PhoneRequiredException();
              receivedPhone = phone;
              return 'https://toyyibpay.com/xyz';
            },
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      // Bukan `pumpAndSettle` - butang "Bayar Sekarang" tunjuk
      // `CircularProgressIndicator.adaptive()` (animasi tak berhenti)
      // sepanjang dialog nombor telefon menunggu input pengguna, jadi
      // `pumpAndSettle` akan timeout menunggu ia berhenti.
      await tester.tap(find.text('Bayar Sekarang'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Nombor Telefon'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '0123456789');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(callCount, 2);
      expect(receivedPhone, '0123456789');
      expect(fakeLauncher.lastUrl, 'https://toyyibpay.com/xyz');
      // Berjaya → pop balik.
      expect(find.text('buka'), findsOneWidget);
    },
  );

  testWidgets('nombor telefon tak sah papar ralat, tak checkout semula', (
    tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(
      host(
        CheckoutRequest(
          title: 'X',
          amountCents: 500,
          currency: 'myr',
          onCheckout: ({phone}) async {
            callCount++;
            if (phone == null) throw PhoneRequiredException();
            return 'https://toyyibpay.com/xyz';
          },
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    // Lihat komen sama dalam ujian "PhoneRequiredException" di atas -
    // spinner tak berhenti sepanjang dialog menunggu, elak `pumpAndSettle`.
    await tester.tap(find.text('Bayar Sekarang'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(callCount, 1); // tak checkout semula lepas nombor tak sah
    expect(
      find.text('Format nombor telefon Malaysia tidak sah'),
      findsOneWidget,
    );
    expect(find.text('Bayar Sekarang'), findsOneWidget); // masih di sini
  });

  testWidgets('ralat generik papar snackbar, tak pop', (tester) async {
    await tester.pumpWidget(
      host(
        CheckoutRequest(
          title: 'X',
          amountCents: 500,
          currency: 'myr',
          onCheckout: ({phone}) async => throw Exception('server down'),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bayar Sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('Gagal proses pembayaran. Cuba lagi.'), findsOneWidget);
    expect(find.text('Bayar Sekarang'), findsOneWidget);
  });
}
