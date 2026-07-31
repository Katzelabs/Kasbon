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
  static const String whatsAppNumber = '6281234567890';

  /// The same number formatted the way an Indonesian user would read it back.
  static const String whatsAppDisplay = '+62 812-3456-7890';

  /// Prefilled first message, so the conversation opens with context.
  static const String whatsAppGreeting =
      'Halo, saya ingin bertanya tentang aplikasi KASBON';

  static const String supportEmail = 'support@kasbon.app';

  static const String termsUrl = 'https://kasbon.app/terms';
  static const String privacyUrl = 'https://kasbon.app/privacy';

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
