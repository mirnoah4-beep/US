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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Ugyldig e-postadresse.';
      case 'weak-password':
        return 'Passordet er for svakt (minst 6 tegn).';
      case 'email-already-in-use':
        return 'Feil e-post eller passord.';
      case 'network-request-failed':
        return 'Nettverksfeil. Sjekk internettforbindelsen.';
      default:
        return 'Noe gikk galt. Prøv igjen.';
    }
  }

  Future<void> _handleAuthSuccess(User user, {bool needsEmailVerification = false}) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirestoreService.saveFcmToken(user.uid, token);
      }
    } catch (_) {}

    await FirestoreService.ensureUserDoc(user, needsEmailVerification: needsEmailVerification);
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
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-post'),
                keyboardType: TextInputType.emailAddress,
                maxLength: 254,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              ),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Passord'),
                obscureText: true,
                maxLength: 128,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final email = _emailController.text.trim();
                  final password = _passwordController.text;
                  if (email.isEmpty || password.isEmpty) {
                    _showError('Fyll inn e-post og passord.');
                    return;
                  }
                  try {
                    await FirebaseAuth.instance.signInWithEmailAndPassword(
                      email: email,
                      password: password,
                    );
                    await FirebaseAnalytics.instance
                        .logLogin(loginMethod: 'email');
                    if (ctx.mounted) Navigator.pop(ctx);
                  } on FirebaseAuthException catch (_) {
                    // Combined "log in / create account" button: sign-in failed,
                    // so try to create the account. If the email already exists,
                    // the real problem was a wrong password — say so instead of
                    // silently doing nothing.
                    try {
                      final cred = await FirebaseAuth.instance
                          .createUserWithEmailAndPassword(
                        email: email,
                        password: password,
                      );
                      final newUser = cred.user;
                      if (newUser == null) {
                        _showError();
                        return;
                      }
                      await newUser.sendEmailVerification();
                      await _handleAuthSuccess(newUser,
                          needsEmailVerification: true);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } on FirebaseAuthException catch (createErr) {
                      if (createErr.code == 'email-already-in-use') {
                        _showError('Feil e-post eller passord.');
                      } else {
                        _showError(_authErrorMessage(createErr));
                      }
                    } catch (_) {
                      _showError();
                    }
                  } catch (_) {
                    _showError();
                  }
                },
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B2E42)),
                child: const Text('Logg inn / Opprett konto'),
              ),
            ],
          ),
        ),
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

