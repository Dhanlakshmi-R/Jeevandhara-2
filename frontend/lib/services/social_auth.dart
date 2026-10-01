import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';

/// Result of a Google sign-in attempt.
/// `idToken` is non-null only on success.
class GoogleAuthResult {
  final String? idToken;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final String? error;

  const GoogleAuthResult({
    this.idToken,
    this.displayName,
    this.email,
    this.photoUrl,
    this.error,
  });

  bool get isSuccess => idToken != null;
}

class SocialAuth {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _initialized = false;

  /// google_sign_in supports Android, iOS, web and macOS only.
  /// Windows/Linux desktop builds fall back with a clear error instead of crashing.
  static bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Must be called exactly once before any other call; re-entrant safe.
  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _googleSignIn.initialize();
      _initialized = true;
    }
  }

  static Future<GoogleAuthResult> signIn() async {
    if (!isSupported) {
      return const GoogleAuthResult(
        error: 'Google login is not available on this device.',
      );
    }

    try {
      await _ensureInitialized();
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return const GoogleAuthResult(
          error: 'Google did not return an ID token.',
        );
      }
      return GoogleAuthResult(
        idToken: idToken,
        displayName: account.displayName,
        email: account.email,
        photoUrl: account.photoUrl,
      );
    } on GoogleSignInException catch (e) {
      return GoogleAuthResult(error: _friendlyError(e.code, e.description));
    } catch (e) {
      return GoogleAuthResult(error: _friendlyError(null, e.toString()));
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Sign-out failures are non-fatal.
    }
  }

  static String _friendlyError(
      GoogleSignInExceptionCode? code, String? detail) {
    switch (code) {
      case GoogleSignInExceptionCode.canceled:
      case GoogleSignInExceptionCode.interrupted:
        return 'Sign-in was cancelled.';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google login isn\'t configured for this app yet. Check the Google Cloud Console settings.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google login couldn\'t show its window. Try again.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Another Google account is signed in. Sign out and try again.';
      default:
        break;
    }
    final text = (detail ?? '').toLowerCase();
    if (text.contains('canceled') ||
        text.contains('cancelled') ||
        text.contains('popup_closed')) {
      return 'Sign-in was cancelled.';
    }
    if (text.contains('network')) {
      return 'Network error while connecting to Google. Try again.';
    }
    if (text.contains('unauthorized_domain') ||
        text.contains('origin_mismatch')) {
      return 'This site is not registered for Google login. Add it in the Google Cloud Console.';
    }
    return 'Google login failed. Please try again.';
  }
}
