import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

const kTermsUrl = 'https://us-app-4bf30.web.app/terms.html';
const kPrivacyUrl = 'https://us-app-4bf30.web.app/privacy.html';

void openLegalUrl(String url) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  void _setLoading(bool value) {
    if (mounted) setState(() => _isLoading = value);
  }

  void _showError([String message = 'Noe gikk galt. Prøv igjen.']) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF993C1D)),
        ),
        backgroundColor: const Color(0xFFFAECE7),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleAuthSuccess(User user, {bool needsEmailVerification = false}) async {
    // The full user document FIRST. saveFcmToken is a merge write: if it ran
    // before ensureUserDoc it created a doc without `coupleId`, which the
    // pairing rules then could not read — the "already has a partner" bug.
    await FirestoreService.ensureUserDoc(user, needsEmailVerification: needsEmailVerification);
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirestoreService.saveFcmToken(user.uid, token);
      }
    } catch (_) {}
    // AuthGate stream handles all navigation from here.
  }

  Future<void> _signInWithApple() async {
    _setLoading(true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oAuth = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oAuth);
      await _handleAuthSuccess(userCredential.user!);
    } catch (_) {
      _setLoading(false);
      _showError();
    }
  }

  void _showEmailLogin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmailAuthSheet(
        onAuthSuccess: _handleAuthSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && Platform.isIOS;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F4),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/logo/us_wordmark.png',
                      width: 140,
                      color: const Color(0xFF8B2E42),
                      colorBlendMode: BlendMode.srcIn,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Bare oss to.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF888780),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 48),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final googleSignIn = GoogleSignIn(
                          serverClientId:
                              '196627223703-a8odmf7vek1bmff7k6vrcin33motbks5.apps.googleusercontent.com',
                          scopes: ['email', 'profile'],
                        );
                        await googleSignIn.signOut();
                        final account = await googleSignIn.signIn();
                        if (account == null) return;
                        final auth = await account.authentication;
                        final credential = GoogleAuthProvider.credential(
                          idToken: auth.idToken,
                          accessToken: auth.accessToken,
                        );
                        final userCredential = await FirebaseAuth.instance
                            .signInWithCredential(credential);
                        if (userCredential.user != null) {
                          await FirebaseAnalytics.instance
                              .logLogin(loginMethod: 'google');
                          await _handleAuthSuccess(userCredential.user!);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Kunne ikke logge inn med Google. Prøv igjen.'),
                              backgroundColor: Color(0xFF333333),
                              duration: Duration(seconds: 6),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Fortsett med Google'),
                  ),
                  TextButton(
                    onPressed: () => _showEmailLogin(context),
                    child: const Text(
                      'Logg inn med e-post',
                      style: TextStyle(color: Color(0xFF8B2E42)),
                    ),
                  ),
                  if (isIOS) ...[
                    const SizedBox(height: 12),
                    _AuthButton(
                      onPressed: _isLoading ? null : _signInWithApple,
                      isLoading: _isLoading,
                      backgroundColor: const Color(0xFF000000),
                      foregroundColor: Colors.white,
                      side: BorderSide.none,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.apple, size: 20, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Fortsett med Apple',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF888780),
                      ),
                      children: [
                        const TextSpan(text: 'Ved å fortsette godtar du våre '),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () => openLegalUrl(kTermsUrl),
                            child: const Text(
                              'Vilkår for bruk',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8B2E42),
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: ' og '),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () => openLegalUrl(kPrivacyUrl),
                            child: const Text(
                              'Personvernerklæring',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8B2E42),
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.onPressed,
    required this.isLoading,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.side,
    required this.child,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final Color backgroundColor;
  final Color foregroundColor;
  final BorderSide side;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: side,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading && onPressed == null
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF8B2E42),
                ),
              )
            : child,
      ),
    );
  }
}

enum _EmailAuthMode { login, create }

/// The email authentication bottom sheet. Login and account creation are two
/// explicit, separate actions — there is no "failed sign-in falls through to
/// create" behaviour. All user-facing auth errors are deliberately generic so
/// the sheet never discloses whether a given email has an account.
class _EmailAuthSheet extends StatefulWidget {
  const _EmailAuthSheet({
    required this.onAuthSuccess,
  });

  final Future<void> Function(User user, {bool needsEmailVerification})
      onAuthSuccess;

  @override
  State<_EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends State<_EmailAuthSheet> {
  _EmailAuthMode _mode = _EmailAuthMode.login;
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _info;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+
  void _switchMode() {
    setState(() {
      _mode = _mode == _EmailAuthMode.login
          ? _EmailAuthMode.create
          : _EmailAuthMode.login;
      _error = null;
      _info = null;
      _obscure = true;
    });
  }

  void _submit() {
    if (_busy) return;
    if (_mode == _EmailAuthMode.login) {
      _login();
    } else {
      _create();
    }
  }

  // LOGIN — only ever signInWithEmailAndPassword. Never auto-creates an
  // account, and reports a single generic message on any failure.
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Fyll inn e-post og passord.';
        _info = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      await FirebaseAnalytics.instance.logLogin(loginMethod: 'email');
      if (mounted) Navigator.pop(context);
      return;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.code == 'network-request-failed'
          ? 'Nettverksfeil. Sjekk internettforbindelsen.'
          : 'Feil e-post eller passord.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Noe gikk galt. Prøv igjen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // CREATE — only ever createUserWithEmailAndPassword. On success it sends the
  // verification email and routes through the existing needsEmailVerification
  // flow (M2 server-authoritative verification stays intact). email-already-
  // in-use is reported with a generic message that does not confirm existence.
  Future<void> _create() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Fyll inn e-post og passord.';
        _info = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = cred.user;
      if (user == null) {
        if (!mounted) return;
        setState(() => _error = 'Noe gikk galt. Prøv igjen.');
        return;
      }
      await user.sendEmailVerification();
      await widget.onAuthSuccess(user, needsEmailVerification: true);
      if (mounted) Navigator.pop(context);
      return;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.code) {
          case 'invalid-email':
            _error = 'Ugyldig e-postadresse.';
            break;
          case 'weak-password':
            _error = 'Passordet er for svakt (minst 6 tegn).';
            break;
          case 'network-request-failed':
            _error = 'Nettverksfeil. Sjekk internettforbindelsen.';
            break;
          default:
            // Includes email-already-in-use: never disclose account existence.
            _error =
                'Kunne ikke opprette konto. Sjekk opplysningene eller prøv å logge inn.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Noe gikk galt. Prøv igjen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // FORGOT PASSWORD — requires a valid email, then sends a reset email. The
  // confirmation copy is neutral: it never reveals whether an account exists,
  // so a user-not-found result is shown exactly like a success.
  Future<void> _forgotPassword() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !_emailRe.hasMatch(email)) {
      setState(() {
        _error = 'Skriv inn e-postadressen din først.';
        _info = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    String? hardError;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        hardError = 'Ugyldig e-postadresse.';
      } else if (e.code == 'network-request-failed') {
        hardError = 'Nettverksfeil. Sjekk internettforbindelsen.';
      }
      // Any other code (e.g. user-not-found) falls through to neutral copy.
    } catch (_) {
      // Ignore: still show neutral copy rather than disclose anything.
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (hardError != null) {
        _error = hardError;
      } else {
        _info =
            'Hvis det finnes en konto med denne e-posten, har vi sendt en lenke for å tilbakestille passordet.';
      }
    });
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    required bool obscure,
    required int maxLength,
    required ValueChanged<String> onSubmitted,
    Widget? suffix,
  }) {
    return TextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      enabled: !_busy,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscure,
      maxLength: maxLength,
      onSubmitted: onSubmitted,
      buildCounter: (_,
              {required currentLength, required isFocused, maxLength}) =>
          null,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.white,
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accentRose, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _EmailAuthMode.login;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isLogin ? 'Velkommen tilbake' : 'Opprett konto',
                  key: const ValueKey('emailAuthHeader'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLogin
                      ? 'Logg inn med e-post'
                      : 'Bare noen få steg, så er dere i gang.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                _field(
                  key: const ValueKey('emailField'),
                  controller: _emailController,
                  focusNode: _emailFocus,
                  hint: 'E-postadresse',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  obscure: false,
                  maxLength: 254,
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 12),
                _field(
                  key: const ValueKey('passwordField'),
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  hint: 'Passord',
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  obscure: _obscure,
                  maxLength: 128,
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                    onPressed:
                        _busy ? null : () => setState(() => _obscure = !_obscure),
                  ),
                ),
                if (isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('emailAuthForgot'),
                      onPressed: _busy ? null : _forgotPassword,
                      child: const Text(
                        'Glemt passord?',
                        style: TextStyle(color: AppTheme.accentRose),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Minst 6 tegn',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.heatRedText,
                      ),
                    ),
                  ),
                if (_info != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _info!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('emailAuthPrimary'),
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentRose,
                      disabledBackgroundColor:
                          AppTheme.accentRose.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isLogin ? 'Logg inn' : 'Opprett konto',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLogin ? 'Ny hos US?' : 'Har du allerede en konto?',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    TextButton(
                      key: const ValueKey('emailAuthSwitch'),
                      onPressed: _busy ? null : _switchMode,
                      child: Text(
                        isLogin ? 'Opprett konto' : 'Logg inn',
                        style: const TextStyle(
                          color: AppTheme.accentRose,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _mode = _mode == _EmailAuthMode.login
          ? _EmailAuthMode.create
          : _EmailAuthMode.login;
      _error = null;
      _info = null;
      _obscure = true;
    });
  }

  void _submit() {
    if (_busy) return;
    if (_mode == _EmailAuthMode.login) {
      _login();
    } else {
      _create();
    }
  }

  // LOGIN — only ever signInWithEmailAndPassword. Never auto-creates an
  // account, and reports a single generic message on any failure.
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Fyll inn e-post og passord.';
        _info = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      await FirebaseAnalytics.instance.logLogin(loginMethod: 'email');
      if (mounted) Navigator.pop(context);
      return;
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.code == 'network-request-failed'
          ? 'Nettverksfeil. Sjekk internettforbindelsen.'
          : 'Feil e-post eller passord.');
    } catch (_) {
      setState(() => _error = 'Noe gikk galt. Prøv igjen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // CREATE — only ever createUserWithEmailAndPassword. On success it sends the
  // verification email and routes through the existing needsEmailVerification
  // flow (M2 server-authoritative verification stays intact). email-already-
  // in-use is reported with a generic message that does not confirm existence.
  Future<void> _create() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Fyll inn e-post og passord.';
        _info = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = cred.user;
      if (user == null) {
        setState(() => _error = 'Noe gikk galt. Prøv igjen.');
        return;
      }
      await user.sendEmailVerification();
      await widget.onAuthSuccess(user, needsEmailVerification: true);
      if (mounted) Navigator.pop(context);
      return;
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'invalid-email':
            _error = 'Ugyldig e-postadresse.';
            break;
          case 'weak-password':
            _error = 'Passordet er for svakt (minst 6 tegn).';
            break;
          case 'network-request-failed':
            _error = 'Nettverksfeil. Sjekk internettforbindelsen.';
            break;
          default:
            // Includes email-already-in-use: never disclose account existence.
            _error =
                'Kunne ikke opprette konto. Sjekk opplysningene eller prøv å logge inn.';
        }
      });
    } catch (_) {
      setState(() => _error = 'Noe gikk galt. Prøv igjen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // FORGOT PASSWORD — requires a valid email, then sends a reset email. The
  // confirmation copy is neutral: it never reveals whether an account exists,
  // so a user-not-found result is shown exactly like a success.
  Future<void> _forgotPassword() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !_emailRe.hasMatch(email)) {
      setState(() {
        _error = 'Skriv inn e-postadressen din først.';
        _info = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    String? hardError;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        hardError = 'Ugyldig e-postadresse.';
      } else if (e.code == 'network-request-failed') {
        hardError = 'Nettverksfeil. Sjekk internettforbindelsen.';
      }
      // Any other code (e.g. user-not-found) falls through to neutral copy.
    } catch (_) {
      // Ignore: still show neutral copy rather than disclose anything.
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (hardError != null) {
        _error = hardError;
      } else {
        _info =
            'Hvis det finnes en konto med denne e-posten, har vi sendt en lenke for å tilbakestille passordet.';
      }
    });
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    required bool obscure,
    required int maxLength,
    required ValueChanged<String> onSubmitted,
    Widget? suffix,
  }) {
    return TextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      enabled: !_busy,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscure,
      maxLength: maxLength,
      onSubmitted: onSubmitted,
      buildCounter: (_,
              {required currentLength, required isFocused, maxLength}) =>
          null,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.white,
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accentRose, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _EmailAuthMode.login;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isLogin ? 'Velkommen tilbake' : 'Opprett konto',
                  key: const ValueKey('emailAuthHeader'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLogin
                      ? 'Logg inn med e-post'
                      : 'Bare noen få steg, så er dere i gang.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                _field(
                  key: const ValueKey('emailField'),
                  controller: _emailController,
                  focusNode: _emailFocus,
                  hint: 'E-postadresse',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  obscure: false,
                  maxLength: 254,
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 12),
                _field(
                  key: const ValueKey('passwordField'),
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  hint: 'Passord',
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  obscure: _obscure,
                  maxLength: 128,
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                    onPressed:
                        _busy ? null : () => setState(() => _obscure = !_obscure),
                  ),
                ),
                if (isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('emailAuthForgot'),
                      onPressed: _busy ? null : _forgotPassword,
                      child: const Text(
                        'Glemt passord?',
                        style: TextStyle(color: AppTheme.accentRose),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Minst 6 tegn',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.heatRedText,
                      ),
                    ),
                  ),
                if (_info != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _info!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('emailAuthPrimary'),
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentRose,
                      disabledBackgroundColor:
                          AppTheme.accentRose.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isLogin ? 'Logg inn' : 'Opprett konto',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLogin ? 'Ny hos US?' : 'Har du allerede en konto?',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    TextButton(
                      key: const ValueKey('emailAuthSwitch'),
                      onPressed: _busy ? null : _switchMode,
                      child: Text(
                        isLogin ? 'Opprett konto' : 'Logg inn',
                        style: const TextStyle(
                          color: AppTheme.accentRose,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

