# Refine Auth (Riverpod + go_router + UI Editorial) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine the existing Supabase email/password auth to use Riverpod for state, go_router for navigation, and a minimal/editorial UI - without changing the core Supabase auth logic.

**Architecture:** Reorganise `lib/` into `app/` (theme + router), `features/{auth,home}/`, and `shared/`. State moves from per-widget `setState`/`_loading` to Riverpod providers (`Provider`, `StreamProvider`, `AsyncNotifier`). Navigation moves from `AuthGate`/`_AuthSwitcher` bool toggling to a `GoRouter` with auth-based `redirect`. No codegen / `build_runner`.

**Tech Stack:** Flutter, `supabase_flutter ^2.16.0`, `flutter_riverpod`, `go_router`, `google_fonts`, `flutter_dotenv`.

## Global Constraints

- No codegen: do NOT add `build_runner`, `riverpod_generator`, or `go_router_builder`.
- Riverpod manual only: `Provider` / `StreamProvider` / `AsyncNotifierProvider`.
- go_router manual only: explicit `GoRoute` list.
- UI language: Bahasa Melayu (keep existing copy strings).
- Palette (no `deepPurple`): bg `#FAF9F6`, ink `#1A1A1A`, accent `#3B7A57`, accent-dark `#1F3D34`, error `#B3261E`, field-fill `#F1EFEA`.
- Typography via `google_fonts`: Fraunces (display/headline), Inter (body/label).
- Preserve Malay error messages in `mapAuthErrorToMessage` and validation rules (email regex, password ≥ 6).
- Dart SDK `^3.12.2` (from pubspec).

---

### Task 1: Add dependencies

**Files:**
- Modify: `pubspec.yaml` (dependencies section)

**Interfaces:**
- Consumes: nothing.
- Produces: packages `flutter_riverpod`, `go_router`, `google_fonts` available to import.

- [ ] **Step 1: Add packages via pub**

Run:
```bash
flutter pub add flutter_riverpod go_router google_fonts
```
Expected: pubspec updated, `flutter pub get` runs clean.

- [ ] **Step 2: Verify resolution**

Run: `flutter pub get`
Expected: "Got dependencies" / no version conflict.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add riverpod, go_router, google_fonts"
```

---

### Task 2: Extract validators into shared/

**Files:**
- Create: `lib/shared/validators.dart`
- Create: `test/shared/validators_test.dart`
- Modify: `lib/services/auth_service.dart` (remove `validateEmail`/`validatePassword`, keep `mapAuthErrorToMessage`, `AuthResult`, `AuthService`) - done in Task 3's move; here only create the new file + delete the two functions' duplication is avoided by doing this before the move. To keep tasks independent, this task ONLY creates `shared/validators.dart` + test and leaves `auth_service.dart` untouched; the old copies are removed in Task 3.

**Interfaces:**
- Consumes: nothing.
- Produces: `String? validateEmail(String?)`, `String? validatePassword(String?)` from `package:marc/shared/validators.dart`.

- [ ] **Step 1: Write the failing test**

Create `test/shared/validators_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/shared/validators.dart';

void main() {
  group('validateEmail', () {
    test('kosong tidak sah', () => expect(validateEmail(''), isNotNull));
    test('format salah tidak sah', () => expect(validateEmail('abc'), isNotNull));
    test('email sah lulus', () => expect(validateEmail('a@b.com'), isNull));
  });

  group('validatePassword', () {
    test('kosong tidak sah', () => expect(validatePassword(''), isNotNull));
    test('pendek tidak sah', () => expect(validatePassword('123'), isNotNull));
    test('cukup panjang lulus', () => expect(validatePassword('123456'), isNull));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/validators_test.dart`
Expected: FAIL - `validators.dart` not found.

- [ ] **Step 3: Create the implementation**

Create `lib/shared/validators.dart`:
```dart
/// Validator email - null = sah.
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

/// Validator kata laluan - null = sah.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Kata laluan diperlukan';
  }
  if (value.length < 6) {
    return 'Kata laluan mesti sekurangnya 6 aksara';
  }
  return null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/validators_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/shared/validators.dart test/shared/validators_test.dart
git commit -m "feat: extract auth validators into shared/"
```

---

### Task 3: Move AuthService into features/auth/

**Files:**
- Create: `lib/features/auth/auth_service.dart`
- Delete: `lib/services/auth_service.dart`
- Modify: any importer of the old path (login/register/home pages) - those pages are rewritten in later tasks, so update their imports there. This task only moves the file and deletes the old validators from it.

**Interfaces:**
- Consumes: nothing new.
- Produces: `AuthService` with `Future<AuthResult> signIn(String,String)`, `Future<AuthResult> signUp(String,String)`, `Future<void> signOut()`; `class AuthResult{bool success; String? error}`; `String mapAuthErrorToMessage(AuthException)` - all from `package:marc/features/auth/auth_service.dart`.

- [ ] **Step 1: Create the moved file (validators removed)**

Create `lib/features/auth/auth_service.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

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
      return const AuthResult(
          success: false, error: 'Sambungan gagal. Semak internet anda');
    }
  }

  Future<AuthResult> signUp(String email, String password) async {
    try {
      await _client.auth.signUp(email: email, password: password);
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: mapAuthErrorToMessage(e));
    } on Exception catch (_) {
      return const AuthResult(
          success: false, error: 'Sambungan gagal. Semak internet anda');
    }
  }

  Future<void> signOut() => _client.auth.signOut();
}
```

- [ ] **Step 2: Delete the old file**

Run: `git rm lib/services/auth_service.dart`
Expected: file removed (old pages still reference it but they are rewritten in later tasks - the app will not compile until Task 9; that is acceptable within this branch).

- [ ] **Step 3: Verify the new file analyzes**

Run: `flutter analyze lib/features/auth/auth_service.dart`
Expected: No issues in this file.

- [ ] **Step 4: Commit**

```bash
git add lib/features/auth/auth_service.dart
git rm lib/services/auth_service.dart
git commit -m "refactor: move AuthService into features/auth, drop inline validators"
```

---

### Task 4: Auth providers + controllers (TDD)

**Files:**
- Create: `lib/features/auth/auth_providers.dart`
- Create: `test/features/auth/login_controller_test.dart`

**Interfaces:**
- Consumes: `AuthService`, `AuthResult` (Task 3).
- Produces:
  - `authServiceProvider` → `Provider<AuthService>`
  - `authStateProvider` → `StreamProvider<AuthState>`
  - `loginControllerProvider` → `AsyncNotifierProvider<LoginController, void>`; `LoginController` has `Future<void> submit(String email, String password)`.
  - `registerControllerProvider` → `AsyncNotifierProvider<RegisterController, void>`; `RegisterController` has `Future<bool> submit(String email, String password)` (returns `true` on success so page can navigate).

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/login_controller_test.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/auth/auth_service.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService(this._result);
  final AuthResult _result;
  @override
  Future<AuthResult> signIn(String email, String password) async => _result;
  @override
  Future<AuthResult> signUp(String email, String password) async => _result;
  @override
  Future<void> signOut() async {}
}

ProviderContainer _containerWith(AuthResult result) {
  final c = ProviderContainer(overrides: [
    authServiceProvider.overrideWithValue(_FakeAuthService(result)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('login berjaya → state AsyncData', () async {
    final c = _containerWith(const AuthResult(success: true));
    await c.read(loginControllerProvider.notifier).submit('a@b.com', '123456');
    expect(c.read(loginControllerProvider).hasError, isFalse);
    expect(c.read(loginControllerProvider).isLoading, isFalse);
  });

  test('login gagal → state AsyncError dengan mesej', () async {
    final c = _containerWith(
        const AuthResult(success: false, error: 'Email atau kata laluan salah'));
    await c.read(loginControllerProvider.notifier).submit('a@b.com', 'wrong1');
    final state = c.read(loginControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error.toString(), contains('Email atau kata laluan salah'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/login_controller_test.dart`
Expected: FAIL - `auth_providers.dart` not found.

- [ ] **Step 3: Create the implementation**

Create `lib/features/auth/auth_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc/features/auth/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<AuthState>(
  (ref) => Supabase.instance.client.auth.onAuthStateChange,
);

class LoginController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit(String email, String password) async {
    state = const AsyncLoading();
    final result = await ref.read(authServiceProvider).signIn(email, password);
    if (result.success) {
      state = const AsyncData(null);
    } else {
      state = AsyncError(result.error ?? 'Log masuk gagal', StackTrace.current);
    }
  }
}

final loginControllerProvider =
    AsyncNotifierProvider<LoginController, void>(LoginController.new);

class RegisterController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Pulang true kalau berjaya (page boleh navigasi + tunjuk mesej).
  Future<bool> submit(String email, String password) async {
    state = const AsyncLoading();
    final result = await ref.read(authServiceProvider).signUp(email, password);
    if (result.success) {
      state = const AsyncData(null);
      return true;
    }
    state = AsyncError(result.error ?? 'Pendaftaran gagal', StackTrace.current);
    return false;
  }
}

final registerControllerProvider =
    AsyncNotifierProvider<RegisterController, void>(RegisterController.new);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/login_controller_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/auth_providers.dart test/features/auth/login_controller_test.dart
git commit -m "feat: riverpod auth providers + login/register controllers"
```

---

### Task 5: App theme (editorial palette + google_fonts)

**Files:**
- Create: `lib/app/theme.dart`

**Interfaces:**
- Consumes: `google_fonts`.
- Produces: `AppColors` (static consts) and `AppTheme.light` → `ThemeData` from `package:marc/app/theme.dart`.

- [ ] **Step 1: Create the theme**

Create `lib/app/theme.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFFFAF9F6);
  static const ink = Color(0xFF1A1A1A);
  static const accent = Color(0xFF3B7A57);
  static const accentDark = Color(0xFF1F3D34);
  static const error = Color(0xFFB3261E);
  static const fieldFill = Color(0xFFF1EFEA);
  static const muted = Color(0xFF6B6B6B);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.fraunces(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        height: 1.1,
      ),
      headlineSmall: GoogleFonts.fraunces(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyMedium: GoogleFonts.inter(fontSize: 15, color: AppColors.muted),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accent,
        secondary: AppColors.accentDark,
        error: AppColors.error,
        surface: AppColors.bg,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        labelStyle: GoogleFonts.inter(color: AppColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentDark,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accentDark),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it analyzes**

Run: `flutter analyze lib/app/theme.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/app/theme.dart
git commit -m "feat: editorial app theme (palette + fraunces/inter)"
```

---

### Task 6: AuthField widget (editorial, TDD)

**Files:**
- Create: `lib/features/auth/widgets/auth_field.dart`
- Delete: `lib/widgets/auth_text_field.dart`
- Create: `test/features/auth/auth_field_test.dart`

**Interfaces:**
- Consumes: nothing new (uses `InputDecorationTheme`).
- Produces: `AuthField({required TextEditingController controller, required String label, IconData? icon, bool obscureText, TextInputType? keyboardType, String? Function(String?)? validator})` from `package:marc/features/auth/widgets/auth_field.dart`.

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/auth_field_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marc/features/auth/widgets/auth_field.dart';

void main() {
  testWidgets('toggle tunjuk/sembunyi menukar keterlihatan', (tester) async {
    final controller = TextEditingController(text: 'rahsia');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AuthField(
          controller: controller,
          label: 'Kata Laluan',
          obscureText: true,
        ),
      ),
    ));

    EditableText field() => tester.widget<EditableText>(find.byType(EditableText));
    expect(field().obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/auth_field_test.dart`
Expected: FAIL - `auth_field.dart` not found.

- [ ] **Step 3: Create the widget**

Create `lib/features/auth/widgets/auth_field.dart`:
```dart
import 'package:flutter/material.dart';

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _obscure = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 20),
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }
}
```

- [ ] **Step 4: Delete the old widget**

Run: `git rm lib/widgets/auth_text_field.dart`
Expected: removed (old pages reference it but are rewritten in Task 7).

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/auth/auth_field_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/auth/widgets/auth_field.dart test/features/auth/auth_field_test.dart
git rm lib/widgets/auth_text_field.dart
git commit -m "feat: editorial AuthField, replace AuthTextField"
```

---

### Task 7: Login & Register pages (editorial + Riverpod)

**Files:**
- Create: `lib/features/auth/login_page.dart`
- Create: `lib/features/auth/register_page.dart`
- Delete: `lib/pages/login_page.dart`, `lib/pages/register_page.dart`

**Interfaces:**
- Consumes: `loginControllerProvider`, `registerControllerProvider` (Task 4); `AuthField` (Task 6); `validateEmail`, `validatePassword` (Task 2).
- Produces: `LoginPage` (route `/login`), `RegisterPage` (route `/register`) - both `ConsumerStatefulWidget`, no constructor callbacks.

- [ ] **Step 1: Create LoginPage**

Create `lib/features/auth/login_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/auth/widgets/auth_field.dart';
import 'package:marc/shared/validators.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(loginControllerProvider.notifier)
        .submit(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final loading = state.isLoading;

    ref.listen(loginControllerProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('${next.error}')));
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 72, 28, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selamat kembali',
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                Text('Log masuk untuk teruskan.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 40),
                AuthField(
                  controller: _email,
                  label: 'Email',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                AuthField(
                  controller: _password,
                  label: 'Kata laluan',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: validatePassword,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: loading ? null : _submit,
                  child: loading
                      ? const _ButtonBusy(label: 'Sedang log masuk…')
                      : const Text('Log Masuk  →'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Belum ada akaun?',
                        style: Theme.of(context).textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('Daftar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonBusy extends StatelessWidget {
  const _ButtonBusy({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
```

- [ ] **Step 2: Create RegisterPage**

Create `lib/features/auth/register_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/auth/widgets/auth_field.dart';
import 'package:marc/shared/validators.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref
        .read(registerControllerProvider.notifier)
        .submit(_email.text.trim(), _password.text);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Pendaftaran berjaya. Semak email untuk pengesahan.')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerControllerProvider);
    final loading = state.isLoading;

    ref.listen(registerControllerProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('${next.error}')));
      }
    });

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Buat akaun',
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                Text('Daftar dengan email anda.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 40),
                AuthField(
                  controller: _email,
                  label: 'Email',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                AuthField(
                  controller: _password,
                  label: 'Kata laluan',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: validatePassword,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: loading ? null : _submit,
                  child: loading
                      ? const _ButtonBusy(label: 'Sedang daftar…')
                      : const Text('Daftar  →'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Sudah ada akaun?',
                        style: Theme.of(context).textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Log masuk'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonBusy extends StatelessWidget {
  const _ButtonBusy({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
```

- [ ] **Step 3: Delete old pages**

Run: `git rm lib/pages/login_page.dart lib/pages/register_page.dart`
Expected: removed.

- [ ] **Step 4: Verify analysis of new pages**

Run: `flutter analyze lib/features/auth/login_page.dart lib/features/auth/register_page.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/login_page.dart lib/features/auth/register_page.dart
git rm lib/pages/login_page.dart lib/pages/register_page.dart
git commit -m "feat: editorial login/register pages driven by riverpod controllers"
```

---

### Task 8: Home page (Consumer + editorial)

**Files:**
- Create: `lib/features/home/home_page.dart`
- Delete: `lib/pages/home_page.dart`

**Interfaces:**
- Consumes: `authServiceProvider` (Task 4).
- Produces: `HomePage` (route `/home`).

- [ ] **Step 1: Create HomePage**

Create `lib/features/home/home_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc/features/auth/auth_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log keluar',
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Anda telah log masuk',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(email, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Delete old home page**

Run: `git rm lib/pages/home_page.dart`
Expected: removed.

- [ ] **Step 3: Verify analysis**

Run: `flutter analyze lib/features/home/home_page.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/home_page.dart
git rm lib/pages/home_page.dart
git commit -m "feat: home page as ConsumerWidget"
```

---

### Task 9: Router + main wiring (delete AuthGate, run full suite)

**Files:**
- Create: `lib/app/router.dart`
- Modify: `lib/main.dart`
- Delete: `lib/pages/auth_gate.dart` (and empty `lib/pages/`, `lib/services/`, `lib/widgets/` dirs)

**Interfaces:**
- Consumes: `authStateProvider` (Task 4), `LoginPage`, `RegisterPage`, `HomePage`, `AppTheme` (Tasks 5,7,8).
- Produces: `routerProvider` → `Provider<GoRouter>`; app boots via `MaterialApp.router`.

- [ ] **Step 1: Create the router**

Create `lib/app/router.dart`:
```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc/features/auth/auth_providers.dart';
import 'package:marc/features/auth/login_page.dart';
import 'package:marc/features/auth/register_page.dart';
import 'package:marc/features/home/home_page.dart';

/// Adapter: dengar Stream, notify GoRouter untuk refresh redirect.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh =
      GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = Supabase.instance.client.auth.currentSession != null;
      final loc = state.matchedLocation;
      final onAuthPage = loc == '/login' || loc == '/register';
      if (loggedIn && onAuthPage) return '/home';
      if (!loggedIn && loc == '/home') return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/home', builder: (_, __) => const HomePage()),
    ],
  );
});
```

Note: `authStateProvider` remains the canonical stream for UI that wants auth state; the router listens to the raw Supabase stream directly to keep `redirect` synchronous via `currentSession`.

- [ ] **Step 2: Rewrite main.dart**

Replace `lib/main.dart` with:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marc/app/router.dart';
import 'package:marc/app/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env belum diisi - salin .env.example ke .env dan isi kredential.
  }
  await Supabase.initialize(
    url: dotenv.get('SUPABASE_URL'),
    publishableKey: dotenv.get('SUPABASE_ANON_KEY'),
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Marc',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
```

- [ ] **Step 3: Delete AuthGate + empty dirs**

Run:
```bash
git rm lib/pages/auth_gate.dart
rmdir lib/pages lib/services lib/widgets 2>/dev/null || true
```
Expected: `auth_gate.dart` removed; old dirs gone if empty.

- [ ] **Step 4: Analyze whole project**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 5: Run full test suite**

Run: `flutter test`
Expected: All tests pass (validators, login controller, auth field).

- [ ] **Step 6: Commit**

```bash
git add lib/app/router.dart lib/main.dart
git rm lib/pages/auth_gate.dart
git commit -m "feat: go_router with auth redirect, wire ProviderScope + MaterialApp.router"
```

---

## Self-Review Notes

- **Spec coverage:** UI editorial (T5,6,7,8), Riverpod manual (T4,7,8), go_router manual redirect (T9), validators moved (T2), AuthService moved (T3). All spec sections mapped.
- **Compile gap:** Tasks 3/6/7 delete files still referenced by not-yet-rewritten code; the tree only compiles again at Task 9. This is intentional for small, reviewable commits on a feature branch - `flutter analyze`/`flutter test` for the whole app is gated at Task 9 Steps 4–5. Per-file `flutter analyze <path>` checks keep each task honest before then.
- **Type consistency:** `loginControllerProvider` (AsyncNotifier<void>, `submit` returns `Future<void>`) and `registerControllerProvider` (`submit` returns `Future<bool>`) used consistently in T7. `AuthField` signature identical in T6 and consumers in T7. `AppColors`/`AppTheme.light` from T5 used in T9.
- **No placeholders:** every code step has full code.
```
