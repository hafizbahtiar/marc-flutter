# Halaman Sign In & Sign Up (Flutter + Supabase) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bina halaman log masuk dan pendaftaran (email + kata laluan) yang berintegrasi dengan Supabase Auth, dengan env config via `flutter_dotenv`.

**Architecture:** `flutter_dotenv` muatkan `.env` (URL + publishable key Supabase) sebagai asset. `main.dart` initialize Supabase, lepas tu jalankan `AuthGate` — `StreamBuilder` atas `onAuthStateChange` yang automatik tukar antara `LoginPage`/`RegisterPage` (tiada session) dan `HomePage` (ada session). `AuthService` balut panggilan Supabase dan petik error ke mesej Melayu. UI guna widget boleh guna semula `AuthTextField`.

**Tech Stack:** Flutter (SDK ^3.12.2), `supabase_flutter ^2.16.0`, `flutter_dotenv`, Material 3, `flutter_test`.

## Global Constraints

- `supabase_flutter: ^2.16.0` (sudah ada di pubspec). Gunakan `Supabase.initialize(url:, publishableKey:)` — parameter moden ialah `publishableKey` (bukan `anonKey`). Key ini = "anon public" key dari dashboard Supabase (selamat dilihat di klien, dilindungi RLS di server).
- Bahasa UI & mesej error: Bahasa Melayu Malaysia.
- Env vars: `SUPABASE_URL` dan `SUPABASE_ANON_KEY` (di dalam `.env`, di-gitignore). `.env.example` ialah template yang di-commit.
- Validasi: email tak kosong + format; password minimum 6 aksara.
- Setiap task berakhir dengan commit. `flutter analyze` mesti lulus sebelum commit.

---

## File Structure

| Fail | Tanggungjawab |
|---|---|
| `pubspec.yaml` | Tambah `flutter_dotenv`, daftar `.env` sebagai asset |
| `.env` | Credentials sebenar (placeholder kini), di-gitignore |
| `.env.example` | Template credentials untuk commit |
| `.gitignore` | Tambah `.env` |
| `lib/services/auth_service.dart` | Fungsi pure (validator, `mapAuthErrorToMessage`) + `AuthService` (signIn/signUp/signOut) |
| `lib/widgets/auth_text_field.dart` | `AuthTextField` boleh guna semula (icon + obscure toggle) |
| `lib/pages/login_page.dart` | UI log masuk + form validasi |
| `lib/pages/register_page.dart` | UI pendaftaran + form validasi |
| `lib/pages/home_page.dart` | Halaman selepas login + butang log keluar |
| `lib/pages/auth_gate.dart` | `StreamBuilder` auth state → Login atau Home |
| `lib/main.dart` | Init dotenv + Supabase, jalankan `AuthGate` |
| `test/auth_text_field_test.dart` | Widget test `AuthTextField` |
| `test/auth_service_test.dart` | Unit test validator + error mapping |

---

## Task 1: Setup env & dependencies

**Files:**
- Modify: `pubspec.yaml`
- Create: `.env`, `.env.example`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `.env` dengan `SUPABASE_URL` & `SUPABASE_ANON_KEY` yang boleh dibaca `flutter_dotenv`; `flutter_dotenv` tersenarai sebagai dependency.

- [ ] **Step 1: Tambah dependency + asset ke `pubspec.yaml`**

Tukar seksyen `dependencies:` (tambah selepas `supabase_flutter`) dan seksyen `flutter:` (tambah `assets:`):

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  supabase_flutter: ^2.16.0
  flutter_dotenv: ^5.2.1
```

```yaml
flutter:
  uses-material-design: true
  assets:
    - .env
```

- [ ] **Step 2: Buat `.env` (placeholder)**

```
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-public-key-here
```

- [ ] **Step 3: Buat `.env.example` (template, akan di-commit)**

```
SUPABASE_URL=
SUPABASE_ANON_KEY=
```

- [ ] **Step 4: Tambah `.env` ke `.gitignore`**

Tambah baris ini ke hujung `.gitignore`:

```
# Env
.env
```

- [ ] **Step 5: Pasang dependency & sahkan**

Run: `flutter pub get`
Expected: tiada error.

Run: `flutter analyze`
Expected: "No issues found!" (atau amaran lama yang tak berkaitan).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock .env.example .gitignore
git commit -m "chore: setup flutter_dotenv & env config untuk Supabase"
```

---

## Task 2: `AuthTextField` widget (TDD)

**Files:**
- Create: `lib/widgets/auth_text_field.dart`
- Test: `test/auth_text_field_test.dart`

**Interfaces:**
- Produces: `AuthTextField({required TextEditingController controller, required String label, required IconData icon, bool obscureText, TextInputType keyboardType, String? Function(String?)? validator})` — widget `FormTextField` yang papar icon, label, dan toggle "tunjuk/sembunyi" bila `obscureText: true`.

- [ ] **Step 1: Tulis widget test yang gagal**

`test/auth_text_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/widgets/auth_text_field.dart';

void main() {
  testWidgets('toggle obscure bila butang mata ditekan', (tester) async {
    final controller = TextEditingController(text: 'secret');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthTextField(
            controller: controller,
            label: 'Kata Laluan',
            icon: Icons.lock,
            obscureText: true,
          ),
        ),
      ),
    );

    // Awalnya tersembunyi
    final editable = tester.widget<EditableText>(
      find.byType(EditableText),
    );
    expect(editable.obscureText, isTrue);

    // Tek butang toggle
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    // Sekarang terbuka
    final editableAfter = tester.widget<EditableText>(
      find.byType(EditableText),
    );
    expect(editableAfter.obscureText, isFalse);
  });
}
```

- [ ] **Step 2: Jalankan test, sahkan gagal**

Run: `flutter test test/auth_text_field_test.dart`
Expected: FAIL — `AuthTextField` tidak dijumpai (import gagal).

- [ ] **Step 3: Implementasi `AuthTextField`**

`lib/widgets/auth_text_field.dart`:

```dart
import 'package:flutter/material.dart';

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscure = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
      obscureText: _obscure,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
    );
  }
}
```

- [ ] **Step 4: Jalankan test, sahkan lulus**

Run: `flutter test test/auth_text_field_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/auth_text_field.dart test/auth_text_field_test.dart
git commit -m "feat: tambah AuthTextField widget dengan toggle obscure"
```

---

## Task 3: Validator & error mapping (TDD, fungsi pure)

**Files:**
- Create: `lib/services/auth_service.dart`
- Test: `test/auth_service_test.dart`

**Interfaces:**
- Produces:
  - `String? validateEmail(String? value)` — null kalau sah, mesej kalau tak.
  - `String? validatePassword(String? value)` — null kalai sah, mesej kalau tak.
  - `String mapAuthErrorToMessage(AuthException e)` — mesej Melayu mengikut kod.
  - `class AuthService` dengan `signIn`, `signUp`, `signOut` (ditambah di Task 4).

- [ ] **Step 1: Tulis unit test yang gagal**

`test/auth_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc/services/auth_service.dart';

void main() {
  group('validateEmail', () {
    test('kosong → mesej error', () {
      expect(validateEmail(''), 'Email diperlukan');
      expect(validateEmail(null), 'Email diperlukan');
    });

    test('format salah → mesej error', () {
      expect(validateEmail('bukan-email'), 'Format email tidak sah');
      expect(validateEmail('user@'), 'Format email tidak sah');
    });

    test('format sah → null', () {
      expect(validateEmail('user@example.com'), isNull);
    });
  });

  group('validatePassword', () {
    test('kosong → mesej error', () {
      expect(validatePassword(''), 'Kata laluan diperlukan');
      expect(validatePassword(null), 'Kata laluan diperlukan');
    });

    test('kurang 6 aksara → mesej error', () {
      expect(validatePassword('12345'), 'Kata laluan mesti sekurangnya 6 aksara');
    });

    test('6+ aksara → null', () {
      expect(validatePassword('123456'), isNull);
    });
  });

  group('mapAuthErrorToMessage', () {
    test('invalid_credentials → mesej Melayu', () {
      final e = AuthException(message: 'x', code: 'invalid_credentials');
      expect(mapAuthErrorToMessage(e), 'Email atau kata laluan salah');
    });

    test('email_not_confirmed → mesej Melayu', () {
      final e = AuthException(message: 'x', code: 'email_not_confirmed');
      expect(mapAuthErrorToMessage(e), 'Sila sahkan email anda dahulu');
    });

    test('user_already_exists → mesej Melayu', () {
      final e = AuthException(message: 'x', code: 'user_already_exists');
      expect(mapAuthErrorToMessage(e), 'Email ini sudah berdaftar');
    });

    test('weak_password → mesej Melayu', () {
      final e = AuthException(message: 'x', code: 'weak_password');
      expect(mapAuthErrorToMessage(e), 'Kata laluan terlalu lemah (minimum 6 aksara)');
    });

    test('kod tidak diketahui → fallback ke mesej asal', () {
      final e = AuthException(message: 'Sesuatu berlaku', code: 'unknown_code');
      expect(mapAuthErrorToMessage(e), 'Sesuatu berlaku');
    });
  });
}
```

- [ ] **Step 2: Jalankan test, sahkan gagal**

Run: `flutter test test/auth_service_test.dart`
Expected: FAIL — `validateEmail` dsb. tidak dijumpai.

- [ ] **Step 3: Implementasi fungsi pure**

Buat `lib/services/auth_service.dart` dengan fungsi pure sahaja buat masa ini (`AuthService` class ditambah di Task 4):

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Validator email — null = sah.
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email diperlukan';
  }
  final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  if (!regex.hasMatch(value.trim())) {
    return 'Format email tidak sah';
  }
  return null;
}

/// Validator kata laluan — null = sah.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Kata laluan diperlukan';
  }
  if (value.length < 6) {
    return 'Kata laluan mesti sekurangnya 6 aksara';
  }
  return null;
}

/// Petik AuthException ke mesej Melayu mesra.
String mapAuthErrorToMessage(AuthException e) {
  switch (e.code) {
    case 'invalid_credentials':
      return 'Email atau kata laluan salah';
    case 'email_not_confirmed':
      return 'Sila sahkan email anda dahulu';
    case 'user_already_exists':
    case 'email_exists':
      return 'Email ini sudah berdaftar';
    case 'weak_password':
      return 'Kata laluan terlalu lemah (minimum 6 aksara)';
    default:
      return e.message;
  }
}
```

- [ ] **Step 4: Jalankan test, sahkan lulus**

Run: `flutter test test/auth_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/auth_service.dart test/auth_service_test.dart
git commit -m "feat: validator & error mapping Melayu untuk auth"
```

---

## Task 4: `AuthService` class (wrapper Supabase)

**Files:**
- Modify: `lib/services/auth_service.dart` (tambah class)

**Interfaces:**
- Consumes: `mapAuthErrorToMessage` (dari Task 3).
- Produces:
  - `class AuthResult { final bool success; final String? error; }`
  - `class AuthService` dengan `Future<AuthResult> signIn(String email, String password)`, `Future<AuthResult> signUp(String email, String password)`, `Future<void> signOut()`.

- [ ] **Step 1: Tambah class ke `lib/services/auth_service.dart`**

Tambah di bawah fungsi pure sedia ada (jangan buang fungsi Task 3):

```dart
/// Hasil operasi auth. `error` null kalau berjaya.
class AuthResult {
  const AuthResult({required this.success, this.error});
  final bool success;
  final String? error;
}

/// Wrapper sekitar Supabase Auth. Boleh inject `SupabaseClient` untuk testing.
class AuthService {
  AuthService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<AuthResult> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: mapAuthErrorToMessage(e));
    } on Exception catch (_) {
      return const AuthResult(success: false, error: 'Sambungan gagal. Semak internet anda');
    }
  }

  Future<AuthResult> signUp(String email, String password) async {
    try {
      await _client.auth.signUp(email: email, password: password);
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: mapAuthErrorToMessage(e));
    } on Exception catch (_) {
      return const AuthResult(success: false, error: 'Sambungan gagal. Semak internet anda');
    }
  }

  Future<void> signOut() => _client.auth.signOut();
}
```

- [ ] **Step 2: Sahkan analyze lulus**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/services/auth_service.dart
git commit -m "feat: AuthService wrapper untuk signIn/signUp/signOut"
```

---

## Task 5: `LoginPage`

**Files:**
- Create: `lib/pages/login_page.dart`

**Interfaces:**
- Consumes: `AuthTextField`, `validateEmail`, `validatePassword`, `AuthService`.
- Produces: `LoginPage({VoidCallback? onRegisterTap})` — papar form log masuk, link ke pendaftaran.

- [ ] **Step 1: Implementasi `LoginPage`**

`lib/pages/login_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:marc/services/auth_service.dart';
import 'package:marc/widgets/auth_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onRegisterTap});

  final VoidCallback? onRegisterTap;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    final result = await _auth.signIn(_email.text.trim(), _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Log masuk gagal')),
      );
    }
    // kalau berjaya, AuthGate akan tukar ke HomePage secara automatik
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Masuk')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_person_outlined, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Selamat datang kembali',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                AuthTextField(
                  controller: _email,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _password,
                  label: 'Kata Laluan',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: validatePassword,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Log Masuk'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: widget.onRegisterTap,
                  child: const Text('Belum ada akaun? Daftar di sini'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Sahkan analyze lulus**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/pages/login_page.dart
git commit -m "feat: halaman log masuk"
```

---

## Task 6: `RegisterPage`

**Files:**
- Create: `lib/pages/register_page.dart`

**Interfaces:**
- Consumes: `AuthTextField`, `validateEmail`, `validatePassword`, `AuthService`.
- Produces: `RegisterPage({VoidCallback? onLoginTap})` — papar form pendaftaran, link ke log masuk.

- [ ] **Step 1: Implementasi `RegisterPage`**

`lib/pages/register_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:marc/services/auth_service.dart';
import 'package:marc/widgets/auth_text_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.onLoginTap});

  final VoidCallback? onLoginTap;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    final result = await _auth.signUp(_email.text.trim(), _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pendaftaran berjaya. Sila semak email untuk pengesahan.')),
      );
      widget.onLoginTap?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Pendaftaran gagal')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akaun')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_add_outlined, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Buat akaun baharu',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                AuthTextField(
                  controller: _email,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _password,
                  label: 'Kata Laluan',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: validatePassword,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Daftar'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: widget.onLoginTap,
                  child: const Text('Sudah ada akaun? Log masuk'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Sahkan analyze lulus**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/pages/register_page.dart
git commit -m "feat: halaman pendaftaran"
```

---

## Task 7: `HomePage`, `AuthGate` & `main.dart`

**Files:**
- Create: `lib/pages/home_page.dart`, `lib/pages/auth_gate.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `AuthService` (signOut), `LoginPage`, `RegisterPage`.
- Produces: app berjalan dengan auth routing automatik.

- [ ] **Step 1: Implementasi `HomePage`**

`lib/pages/home_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    // AuthGate akan tukar ke LoginPage secara automatik
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laman Utama'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Keluar',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                'Anda telah log masuk',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(user?.email ?? ''),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implementasi `AuthGate`**

`lib/pages/auth_gate.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc/pages/home_page.dart';
import 'package:marc/pages/login_page.dart';
import 'package:marc/pages/register_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initial,
        Supabase.instance.client.auth.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session != null) {
          return const HomePage();
        }
        return Navigator(
          onGenerateRoute: (settings) {
            if (settings.name == '/register') {
              return MaterialPageRoute(
                builder: (_) => RegisterPage(
                  onLoginTap: () => Navigator.pop(context),
                ),
              );
            }
            return MaterialPageRoute(
              builder: (_) => LoginPage(
                onRegisterTap: () => Navigator.pushNamed(context, '/register'),
              ),
            );
          },
        );
      },
    );
  }
}
```

- [ ] **Step 3: Ganti `main.dart`**

`lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc/pages/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.get('SUPABASE_URL'),
    publishableKey: dotenv.get('SUPABASE_ANON_KEY'),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marc',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const AuthGate(),
    );
  }
}
```

- [ ] **Step 4: Sahkan analyze & test lulus**

Run: `flutter analyze`
Expected: "No issues found!"

Run: `flutter test`
Expected: semua test PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/home_page.dart lib/pages/auth_gate.dart lib/main.dart
git commit -m "feat: AuthGate, HomePage & init Supabase"
```

---

## Selepas pelaksanaan — langkah pengguna

1. Buat project di [supabase.com](https://supabase.com).
2. Salin **Project URL** dan **anon public key** dari `Settings → API`.
3. Tampal ke `.env` (gantikan placeholder). Jangan commit `.env`.
4. Di dashboard Supabase → `Authentication → Providers → Email`: aktifkan, dan (pilihan) matikan "Confirm email" kalau nak login terus tanpa pengesahan buat ujian.
5. `flutter run`.

## Self-Review (selepas tulis plan)

- **Spec coverage:** sign in ✓ (Task 5), sign up ✓ (Task 6), env setup ✓ (Task 1), AuthService ✓ (Task 4), AuthGate ✓ (Task 7), error Melayu ✓ (Task 3), validasi ✓ (Task 3), testing ✓ (Task 2 & 3). Semua seksyen spec diliputi.
- **Placeholder scan:** tiada TBD/TODO; semua kod disertakan penuh.
- **Type consistency:** `AuthResult{success, error}`, `AuthService.signIn/signUp/signOut`, `validateEmail/validatePassword`, `mapAuthErrorToMessage`, `AuthTextField` — nama & tandatangan konsisten antara task.