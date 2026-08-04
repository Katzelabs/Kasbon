/// Auth failure codes the UI branches on.
///
/// [AuthFailure.code] otherwise carries Supabase's HTTP status, which is `400`
/// for a wrong password and `400` for an unconfirmed email alike - useless to
/// anything deciding where to send the user next. The datasource substitutes
/// one of these when it recognises the underlying error, so callers can match
/// on a constant instead of on the Bahasa Indonesia copy, which is written for
/// humans and will be reworded.
class AuthErrorCodes {
  AuthErrorCodes._();

  /// Credentials were right; the address has never been confirmed.
  static const String emailNotConfirmed = 'email_not_confirmed';

  /// A verification or recovery code was wrong, or has expired. Supabase does
  /// not distinguish the two - see the note in `_mapAuthErrorMessage`.
  static const String invalidOtp = 'invalid_otp';

  /// The password re-entered to authorise a destructive action was wrong.
  ///
  /// Distinct from a failed login even though both come from
  /// `signInWithPassword`: the user is already signed in, so "email atau
  /// password salah" would be nonsense - there is only one field, and it is the
  /// password. The delete-account dialog shows this against that field rather
  /// than as a banner.
  static const String wrongPassword = 'wrong_password';
}
