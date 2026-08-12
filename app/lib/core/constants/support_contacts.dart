/// Where the app sends a user who wants help, and where the legal pages live.
///
/// These were literals inside `about_screen.dart` - the support address written
/// once as a subtitle and again inside the `mailto:` builder, so the row could
/// advertise one mailbox while the tap opened another. Anything user-facing
/// here is meant to be read as well as launched, so the display string and the
/// URI are derived from one value.
class SupportContacts {
  SupportContacts._();

  /// Support number in international form, no `+` - what `wa.me` expects.
  static const String whatsAppNumber = '6285333416372';

  /// The same number formatted the way an Indonesian user would read it back.
  static const String whatsAppDisplay = '+62 853-3341-6372';

  /// Prefilled first message, so the conversation opens with context.
  static const String whatsAppGreeting =
      'Halo, saya ingin bertanya tentang aplikasi KASBON';

  static const String supportEmail = 'kasbon@katzeapps.com';

  /// The published terms of service.
  ///
  /// Same arrangement as [privacyUrl]: `app/web/legal/terms.html` ships inside
  /// the web build, so the URL path is the file path. This pointed at
  /// `/terms` - a path nothing served - while the row for it sat live in
  /// *Tentang Aplikasi → Legal*.
  static const String termsUrl = 'https://kasbonapp.katzeapps.com/legal/terms.html';

  /// The published privacy policy.
  ///
  /// This is the same URL declared in the Play Console and App Store Connect,
  /// and both stores check that it resolves - so it points at a file that
  /// actually ships rather than at a path someone intends to create.
  /// `app/web/legal/privacy.html` is copied into the web build verbatim, so
  /// whatever host serves the web app serves the policy at this address.
  static const String privacyUrl = 'https://kasbonapp.katzeapps.com/legal/privacy.html';

  /// The account-deletion page, declared in the Play Console as the app's
  /// deletion URL.
  ///
  /// Play requires *both* an in-app route and a web-reachable one, and the web
  /// one has to work for someone who no longer has the app installed - which is
  /// why it is a page describing the two routes rather than a link back into
  /// the app. Same arrangement as [privacyUrl]: `app/web/legal/hapus-akun.html`
  /// ships inside the web build, so the URL path is the file path.
  static const String accountDeletionUrl =
      'https://kasbonapp.katzeapps.com/legal/hapus-akun.html';

  /// Deep link into WhatsApp with the greeting already typed.
  static Uri get whatsAppUri => Uri.parse(
        'https://wa.me/$whatsAppNumber'
        '?text=${Uri.encodeComponent(whatsAppGreeting)}',
      );

  /// `mailto:` for the support inbox, with a subject the triage can filter on.
  static Uri get supportEmailUri => Uri(
        scheme: 'mailto',
        path: supportEmail,
        query: 'subject=${Uri.encodeComponent('Bantuan KASBON')}',
      );
}
