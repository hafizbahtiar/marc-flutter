# MARC (Flutter)

App komuniti MARC. Backend: repo `marc_go` (sibling) - Go + Gin + Postgres.

[`TODO.md`](./TODO.md) untuk kerja yang belum siap.
[`PAYMENT-STRIPE.md`](./PAYMENT-STRIPE.md) untuk aliran donation.

> **MARC bukan aplikasi rasmi MAIWP.** Ia dibangunkan secara sukarela sebagai
> projek peribadi, dan tidak diurus, ditaja atau disahkan oleh MAIWP. Framing
> ni mesti kekal konsisten merentas halaman Tentang, FAQ, dan resit donation -
> lihat nota dalam `PAYMENT-STRIPE.md`.

## Stack

- **Flutter 3.44** / Dart 3.12
- **Riverpod** - state (`NotifierProvider`, `AsyncNotifier`, `FutureProvider.family`)
- **GoRouter** - routing, dengan `StatefulShellRoute` untuk bottom nav
- **Dio** - HTTP + interceptor auto-refresh token
- **flutter_secure_storage** - token (Keychain/Keystore)
- **flutter_stripe** - PaymentSheet (kad + FPX)
- **extended_image** - cache gambar + zum/leret-tutup
- **OneSignal** - push

## Setup

```bash
flutter pub get

cp .env.example .env   # kalau ada; jika tidak, cipta .env
```

`.env` perlukan:

```
API_BASE_URL=http://10.0.2.2:8080     # emulator Android → localhost host
STRIPE_PUBLISHABLE_KEY=pk_test_...     # bukan rahsia, selamat di client
ONESIGNAL_APP_ID=...                   # optional
```

```bash
flutter run
```

## Struktur

```
lib/
  app/          - theme (light/dark + AppSemanticColors), router, init Stripe
  core/         - api_client (Dio + auth interceptor), auth_state,
                  token_storage, error_utils, app_log, theme_mode_provider
  features/
    auth/       - login, register, sesi
    posts/      - feed, detail, karang, grid gambar + pemapar skrin penuh
    members/    - direktori ahli, barisan kelulusan, tukar role
    profile/    - profil, tentang, FAQ, edit
    donation/   - borang sokongan + handler gateway (Strategy)
    audit/      - pemapar jejak audit (management sahaja)
    notifications/
  shared/widgets/ - AppDialogShell, AppActionSheet, AppNetworkImage,
                    EditedBadge, MySnackBar, ConfirmDialog
```

## Corak yang mesti diikut

Perkara yang pernah jadi bug di sini, jadi ia bukan sekadar gaya:

- **Provider data MESTI watch `isLoggedIn`.** Provider bukan-`autoDispose`
  yang tak watch status log masuk akan kekal memegang data user sebelum
  selepas logout, dan menghidangkannya kepada sesi seterusnya pada peranti
  yang sama. Guna
  `ref.watch(authNotifierProvider.select((s) => s.isLoggedIn))`.
- **Bezakan "memuat" daripada "tiada akses".**
  `valueOrNull?.isManagement ?? false` ialah `false` semasa profil masih
  dimuat, jadi ahli pengurusan yang sah nampak kilasan "tiada akses". Semak
  `isLoading` dahulu.
- **Overlay skrin penuh perlu `rootNavigator: true`.** `/feed` tinggal
  dalam `StatefulShellRoute`, jadi `Navigator.of(context)` biasa menolak
  DALAM shell (bar navigasi kekal nampak).
- **Teks di luar `Scaffold` perlu moyang `Material`.** Tanpanya Flutter
  melukis garis bawah berganda kuning, dan menetapkan `color` pada
  `TextStyle` tak membuangnya.
- **Gambar rangkaian: guna `AppNetworkImage`.** Ia mengekang saiz nyahkod.
  `Image.network` mentah menyahkod pada resolusi penuh - sumber 3456×4608
  ialah ~64MB dalam memori untuk satu gambar.
- **Butang dalam susun atur tak berhad**: `filledButtonTheme` global
  menetapkan `minimumSize: Size.fromHeight(54)`, iaitu lebar TAK TERHINGGA.
  Dalam `AppBar.actions` atau `Row` tanpa `Expanded` ia meletup.

## Testing

```bash
flutter analyze
flutter test
dart format lib/ test/
```

Nota: `pumpAndSettle()` tak pernah selesai pada skrin yang ada gambar
rangkaian - spinner "memuat" berpusing selamanya sebab muat turun tak
berlaku dalam ujian. Guna `pump(Duration(...))` berjadual.

## Build

```bash
flutter build apk --debug
flutter build apk --release
```

Android: `MainActivity` mesti `FlutterFragmentActivity` (keperluan
flutter_stripe), dan tema mesti `Theme.MaterialComponents.*`.
`permission_handler` dipin ke 12.0.3 - 13.x tarik transitive yang perlukan
compileSdk 37 yang AGP semasa tak dapat resolve.
