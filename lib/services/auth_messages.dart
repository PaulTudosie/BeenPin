import 'package:supabase_flutter/supabase_flutter.dart';

String authErrorMessage(Object error) {
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'Email or password is incorrect. Please try again.';
      case 'user_already_exists':
      case 'email_exists':
        return 'An account already uses this email. Please sign in.';
      case 'weak_password':
        return 'Choose a stronger password with more characters, letters and numbers.';
      case 'email_not_confirmed':
        return 'Please confirm your email before signing in.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'email_address_invalid':
      case 'validation_failed':
        return 'Check your email and password, then try again.';
    }
  }
  if (error is PostgrestException && error.code == '23505') {
    return 'That username is already taken. Choose another username.';
  }
  return 'Unable to connect or complete this request. Check your connection and try again.';
}
