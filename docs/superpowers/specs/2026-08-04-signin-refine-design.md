# Design: Refine Auth — Riverpod + go_router + UI Editorial

Tarikh: 2026-08-04
Projek: `marc_flutter` (Flutter, `supabase_flutter: ^2.16.0`)
Status: refine ke atas kerja sedia ada (sign in / sign up Supabase)

## Tujuan
Memperhalusi ciri auth sedia ada tanpa mengubah logik Supabase teras. Tiga matlamat:
1. **UI/UX** — buang rupa "template AI"; gaya minimal/editorial yang matang.
2. **Riverpod** — ganti `setState` + `AuthService()` per-widget dengan provider (manual, tiada codegen).
3. **Routing** — ganti `AuthGate`/`_AuthSwitcher` (`setState` bool) dengan `go_router` (manual, redirect berasaskan auth state).

Prinsip: **tiada `build_runner`/codegen** untuk mana-mana bahagian.

## Keputusan (disahkan pengguna)
- Routing: `go_router` **manual** (senarai `GoRoute`, tiada `go_router_builder`).
- State: Riverpod **manual** (`Provider` / `StreamProvider` / `AsyncNotifier`), tiada `riverpod_generator`.
- Gaya UI: **minimal / editorial** — kiri-align, hero besar, aksen matang (bukan ungu), banyak ruang putih.
- Typography: `google_fonts` — serif (Fraunces) untuk hero, sans (Inter) untuk badan.
- Bahasa UI: kekal Bahasa Melayu.
- Skop kekal: sign in + sign up sahaja. Tiada reset password, tiada dwibahasa, tiada deep-link parametrik.

## Arah Reka Bentuk (elak rupa template)
- **Palet:** buang `Colors.deepPurple`.
  - Latar: `#FAF9F6` (off-white / kertas)
  - Ink / teks utama: `#1A1A1A`
  - Aksen (butang, underline fokus, link): hijau dalam `#3B7A57`, varian gelap `#1F3D34`
  - Ralat: `#B3261E` (bukan merah tepu default)
- **Layout:** kiri-align, bukan center simetri. Ruang putih besar di atas → hero serif → subteks → borang → butang. Tiada `Icon(size: 64)` di tengah.
- **Field:** gaya `filled` lembut (fill `#F1EFEA`, tiada outline tebal), underline/border fokus bertukar ke aksen. Label kecil di atas atau `floatingLabel`.
- **Butang:** rounded sederhana (radius ~10), teks + `→`, warna aksen tetapi tidak "neon". Lebar penuh dibenarkan tetapi ketinggian selesa (~52).
- **Loading:** butang bertukar teks ("Sedang log masuk…") + spinner kecil sewarna teks butang; bukan `CircularProgressIndicator` biru default berasingan.

## Senibina & Struktur Fail (selepas refine)

```
lib/
├── main.dart                       # init dotenv + Supabase, ProviderScope, MaterialApp.router
├── app/
│   ├── router.dart                 # GoRouter + redirect ikut auth state (refreshListenable)
│   └── theme.dart                  # AppTheme: warna, textTheme google_fonts, input/button theme
├── features/
│   ├── auth/
│   │   ├── auth_service.dart        # (dipindah dari lib/services/) wrapper Supabase — kekal
│   │   ├── auth_providers.dart      # authServiceProvider, authStateProvider, login/registerController
│   │   ├── login_page.dart          # (dipindah + reka semula editorial)
│   │   ├── register_page.dart       # (dipindah + reka semula editorial)
│   │   └── widgets/
│   │       └── auth_field.dart      # (dipindah dari widgets/auth_text_field.dart, gaya editorial)
│   └── home/
│       └── home_page.dart           # (dipindah, kemas ringan)
└── shared/
    └── validators.dart              # validateEmail / validatePassword (dipindah dari auth_service.dart)
```

Fail dibuang: `lib/pages/auth_gate.dart` (digantikan router redirect), `lib/pages/*` & `lib/services/*` & `lib/widgets/*` (dipindah ke struktur `features/`).

## Komponen

### main.dart
- `WidgetsFlutterBinding.ensureInitialized()`.
- `await dotenv.load(...)` (kekal cuba/tangkap).
- `await Supabase.initialize(...)` (kekal).
- Bungkus dengan `ProviderScope`.
- `MyApp` guna `MaterialApp.router(routerConfig: ref.watch(routerProvider), theme: AppTheme.light)`.

### app/theme.dart
- `AppTheme.light` — `ColorScheme` dibina manual dari palet di atas (bukan `fromSeed(deepPurple)`).
- `textTheme` = gabungan `GoogleFonts.frauncesTextTheme` (display/headline) + `GoogleFonts.inter` (body/label).
- `InputDecorationTheme` (filled, radius, warna fokus aksen), `FilledButtonTheme` / `ElevatedButtonTheme` seragam supaya page tak ulang styling.

### app/router.dart
- `routerProvider = Provider<GoRouter>((ref) {...})`.
- Route: `/login`, `/register`, `/home`. `initialLocation: '/login'`.
- `refreshListenable`: `GoRouterRefreshStream(ref.watch(authStateProvider.stream))` atau setara — router refresh bila auth berubah.
- `redirect(context, state)`:
  - `loggedIn = ref.read(authStateProvider).value?.session != null` (atau baca `currentSession`).
  - Jika `loggedIn` dan lokasi ∈ {`/login`,`/register`} → `/home`.
  - Jika `!loggedIn` dan lokasi = `/home` → `/login`.
  - Selainnya `null`.
- Navigasi Login↔Register: `context.push('/register')` / `context.pop()` — ada transisi + butang back.

### features/auth/auth_providers.dart
- `authServiceProvider = Provider((ref) => AuthService());`
- `authStateProvider = StreamProvider<AuthState>((ref) => Supabase.instance.client.auth.onAuthStateChange);`
  — sumber kebenaran redirect.
- `loginControllerProvider = AsyncNotifierProvider<LoginController, void>(LoginController.new);`
  - `LoginController extends AsyncNotifier<void>`; `build()` kembali `void`/null (idle).
  - `Future<void> submit(email, password)`: set `state = AsyncLoading()`, panggil `authService.signIn`, jika `!success` → `state = AsyncError(mesej)`; jika berjaya → `state = AsyncData(null)` (redirect diuruskan router).
- `registerControllerProvider` — corak sama guna `signUp`; kejayaan → sampaikan mesej "semak email" + pop ke `/login`.

### features/auth/login_page.dart & register_page.dart
- `ConsumerStatefulWidget` (perlu `TextEditingController` + `dispose`).
- `ref.watch(loginControllerProvider).isLoading` → kawal butang loading.
- `ref.listen(loginControllerProvider, ...)` → papar `SnackBar` pada `AsyncError`.
- Susun atur editorial (lihat Arah Reka Bentuk). Tiada `_loading` lokal, tiada `AuthService()` langsung.

### features/auth/widgets/auth_field.dart
- Kekal API asas (`controller`, `label`, `obscureText`, `keyboardType`, `validator`) + ikon opsyenal.
- Reka semula ikut gaya editorial (filled, fokus aksen, toggle tunjuk/sembunyi untuk password).

### features/home/home_page.dart
- `ConsumerWidget`; butang log keluar panggil `ref.read(authServiceProvider).signOut()`.
- Kemas ringan mengikut tema baharu (tidak lagi `Icons.check_circle` hijau default besar; guna susun atur editorial).

### shared/validators.dart
- Pindahkan `validateEmail`, `validatePassword` keluar dari `auth_service.dart` (pemisahan tanggungjawab). `mapAuthErrorToMessage` kekal dekat `AuthService`.

## Data Flow

### Log masuk
```
User tekan "Log Masuk"
  → LoginPage.validate() (Form)
  → ref.read(loginControllerProvider.notifier).submit(email, password)
  → AsyncLoading (butang → "Sedang log masuk…")
  → AuthService.signIn → Supabase signInWithPassword
  → gagal: AsyncError → ref.listen → SnackBar mesej Melayu
  → berjaya: auth stream keluar session baharu
      → authStateProvider refresh → GoRouter refreshListenable
      → redirect ke /home automatik
```

### Log keluar
```
HomePage butang log keluar → authService.signOut()
  → auth stream keluar (session null)
  → router redirect → /login
```

## Error Handling & Validasi
- Kekal `mapAuthErrorToMessage` (mesej Melayu) dalam `AuthService`.
- Kekal peraturan validasi: email tak kosong + regex; password ≥ 6 aksara.
- Ralat auth dipapar via `SnackBar` (bukan inline) melalui `ref.listen`.

## Testing
- Unit: `validators.dart` — kes kosong / format salah / sah.
- Unit: `LoginController`/`RegisterController` dengan `AuthService` palsu (inject melalui override provider) — sahkan peralihan `loading → error` dan `loading → data`.
- Widget: `AuthField` — toggle tunjuk/sembunyi menukar `obscureText`.
- Tidak menguji panggilan Supabase sebenar (perlukan projek/rangkaian).

## Kebergantungan Baharu (pubspec)
- `flutter_riverpod`
- `go_router`
- `google_fonts`

## Langkah Pelaksanaan (ringkas)
1. Tambah `flutter_riverpod`, `go_router`, `google_fonts` ke `pubspec.yaml`.
2. Cipta `app/theme.dart` (palet + google_fonts + input/button theme).
3. Pindah `services/auth_service.dart` → `features/auth/auth_service.dart`; ekstrak validators → `shared/validators.dart`.
4. Cipta `features/auth/auth_providers.dart` (service + stream + controllers).
5. Cipta `app/router.dart` (GoRouter + redirect + refreshListenable).
6. Pindah + reka semula `login_page.dart`, `register_page.dart`, `auth_field.dart`, `home_page.dart`.
7. Kemas kini `main.dart` (`ProviderScope` + `MaterialApp.router`).
8. Buang `lib/pages/auth_gate.dart` dan fail lama yang telah dipindah.
9. Tulis ujian (validators, controllers, AuthField).
10. `flutter analyze` + `flutter test`.
