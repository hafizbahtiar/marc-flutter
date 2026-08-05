# Design: Halaman Sign In & Sign Up (Flutter + Supabase)

Tarikh: 2026-08-04
Projek: `marc` (Flutter, `supabase_flutter: ^2.16.0`)

## Tujuan
Membina halaman log masuk (sign in) dan pendaftaran (sign up) menggunakan email + kata laluan, dengan Supabase Auth. Pengguna belum ada project Supabase; credentials akan diisi sendiri kemudian. Env disediakan sekali supaya senang diisi.

## Keputusan
- Skop: sign in + sign up (tiada reset kata laluan buat masa ini).
- Kaedah auth: email + kata laluan sahaja.
- Env: Pendekatan A — `flutter_dotenv` (fail `.env` sebagai asset, `.gitignore`).
- Bahasa UI: Bahasa Melayu Malaysia.

## Senibina & Struktur Fail

```
lib/
├── main.dart                      # Init dotenv + Supabase, jalankan AuthGate
├── services/
│   └── auth_service.dart           # Wrapper Supabase auth (signIn/signUp/signOut)
├── pages/
│   ├── auth_gate.dart              # Stream auth state → Login atau Home
│   ├── login_page.dart             # UI sign in (email + password)
│   ├── register_page.dart          # UI sign up (email + password)
│   └── home_page.dart              # Halaman selepas login (ganti counter demo)
└── widgets/
    └── auth_text_field.dart        # TextField boleh guna semula (icon + obscure)
.env                                # SUPABASE_URL + SUPABASE_ANON_KEY (placeholder, di-gitignore)
.env.example                        # Versi template untuk commit
```

## Komponen

### main.dart
- `await dotenv.load(fileName: ".env")` sebelum `runApp`.
- `Supabase.initialize(url: dotenv['SUPABASE_URL'], anonKey: dotenv['SUPABASE_ANON_KEY'])`.
- Jalankan `AuthGate` sebagai root widget.

### AuthGate
- `StreamBuilder` atas `Supabase.instance.client.auth.onAuthStateChange`.
- Nilai awal stream: semak `Supabase.instance.client.auth.currentUser` (supaya tak ada flash LoginPage ketika app start dengan session sedia ada).
- Ada session → `HomePage`; tiada → `LoginPage`.
- Navigation automatik bila login/logout (tak perlu `Navigator.push` manual).

### AuthService
Class statik:
- `signIn(email, password)` → `AuthResult{success, error?}`
- `signUp(email, password)` → `AuthResult{success, error?}`
- `signOut()`
- Tangkap `AuthException`, petik kod, pulang mesej Melayu mesra.

### LoginPage / RegisterPage
- `StatefulWidget`, form dengan `GlobalKey<FormState>`.
- `AuthTextField` email + password.
- Butang utama dengan loading state (`CircularProgressIndicator`).
- Link navigasi antara dua halaman di bawah.

### AuthTextField
Parameter: `label`, `icon`, `obscureText`, `keyboardType`, `controller`, `validator`.
`OutlineInputBorder` rounded, padding 12. Toggle "tunjuk/sembunyi" untuk password.

## Data Flow

### Log masuk
```
User tekan "Log Masuk"
  → LoginPage.validate()
  → AuthService.signIn(email, password)
  → Supabase.client.auth.signInWithPassword(...)
  → AuthResult{success, error?}
  → gagal: SnackBar mesej Melayu
  → berjaya: AuthGate stream detect session → auto ke HomePage
```

### Log keluar
`HomePage` butang "Log Keluar" → `AuthService.signOut()` → stream false → auto balik `LoginPage`.

## Error Handling (mesej Melayu)
`AuthService` tangkap `AuthException`, petik kod, pulang mesej Melayu:
- `invalid_credentials` → "Email atau kata laluan salah"
- `email_not_confirmed` → "Sila sahkan email anda dahulu"
- `user_already_exists` / `email_exists` → "Email ini sudah berdaftar"
- `weak_password` → "Kata laluan terlalu lemah (minimum 6 aksara)"
- rangkaian gagal → "Sambungan gagal. Semak internet anda"
- fallback → mesej asal `AuthException`

## Validasi Form
- Email: tak kosong + format `RegExp`.
- Password: minimum 6 aksara.
- Papar error di bawah medan.

## Testing
- Widget test `AuthTextField`: toggle obscure berfungsi.
- `AuthService` dengan mock: return `AuthResult` betul bila input kosong.
- Tak cover panggilan Supabase sebenar (perlukan project).

## Langkah Pelaksanaan (ringkas)
1. Tambah `flutter_dotenv` ke `pubspec.yaml`, masukkan `.env` ke assets.
2. Buat `.env` (placeholder) + `.env.example` + kemas kini `.gitignore`.
3. `lib/services/auth_service.dart`.
4. `lib/widgets/auth_text_field.dart`.
5. `lib/pages/login_page.dart`, `register_page.dart`, `home_page.dart`, `auth_gate.dart`.
6. `lib/main.dart` (init + AuthGate).
7. Widget test.