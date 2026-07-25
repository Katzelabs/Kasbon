import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/modern/modern.dart';

/// Utility class for sharing content via various channels
///
/// Provides methods for:
/// - Copying text to clipboard
/// - Sharing via system share sheet
/// - Sharing via WhatsApp (with Indonesian phone number support)
class ShareHelper {
  ShareHelper._();

  /// Copy text to clipboard and show confirmation toast
  ///
  /// [context] - BuildContext for showing toast
  /// [text] - Text to copy
  /// [successMessage] - Custom success message (default: 'Berhasil disalin ke clipboard')
  static Future<void> copyToClipboard(
    BuildContext context,
    String text, {
    String successMessage = 'Berhasil disalin ke clipboard',
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ModernToast.success(context, successMessage);
      }
    } catch (e) {
      if (context.mounted) {
        ModernToast.error(context, 'Gagal menyalin ke clipboard');
      }
    }
  }

  /// Share text via system share sheet
  ///
  /// [text] - Text to share
  /// [subject] - Optional subject for email apps
  /// [sharePositionOrigin] - Optional position for iPad share popover
  static Future<void> shareText(
    String text, {
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    await Share.share(
      text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Share text via WhatsApp
  ///
  /// Opens WhatsApp with pre-filled message.
  /// If phone number is provided, opens chat with that number.
  ///
  /// Handles Indonesian phone number formats:
  /// - 0812... -> 62812...
  /// - +62812... -> 62812...
  /// - 62812... -> 62812...
  ///
  /// [context] - BuildContext for showing error toast
  /// [text] - Text to share
  /// [phoneNumber] - Optional phone number to send to
  ///
  /// Returns true if WhatsApp was opened successfully
  static Future<bool> shareViaWhatsApp(
    BuildContext context,
    String text, {
    String? phoneNumber,
  }) async {
    try {
      // Clean phone number (remove spaces, dashes, etc.)
      String? cleanPhone;
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
        // Convert Indonesian local format to international
        if (cleanPhone.startsWith('0')) {
          cleanPhone = '62${cleanPhone.substring(1)}';
        } else if (!cleanPhone.startsWith('+') &&
            !cleanPhone.startsWith('62')) {
          cleanPhone = '62$cleanPhone';
        }
        cleanPhone = cleanPhone.replaceAll('+', '');
      }

      // Encode the text for URL
      final encodedText = Uri.encodeComponent(text);

      // Use wa.me URL which works reliably without package visibility declarations
      // This URL opens in browser first, then redirects to WhatsApp app
      final whatsappUrl = Uri.parse(
        cleanPhone != null
            ? 'https://wa.me/$cleanPhone?text=$encodedText'
            : 'https://wa.me/?text=$encodedText',
      );

      // Launch directly without checking canLaunchUrl first
      // On Android 11+, canLaunchUrl may return false due to package visibility
      // restrictions even when WhatsApp is installed
      final launched = await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        // If launch failed, show error
        ModernToast.error(context, 'Gagal membuka WhatsApp');
      }

      return launched;
    } catch (e) {
      if (context.mounted) {
        ModernToast.error(context, 'Gagal membuka WhatsApp');
      }
      return false;
    }
  }

  /// Show share options bottom sheet
  ///
  /// Displays options for:
  /// - Copy to clipboard
  /// - Share via WhatsApp
  /// - Share via other apps
  ///
  /// [context] - BuildContext
  /// [text] - Text to share
  /// [subject] - Optional subject for share
  /// [phoneNumber] - Optional phone number for WhatsApp
  static Future<void> showShareOptions(
    BuildContext context, {
    required String text,
    String? subject,
    String? phoneNumber,
  }) async {
    final result = await ModernBottomSheet.showActions(
      context,
      title: 'Bagikan Struk',
      actions: const [
        ModernBottomSheetAction(
          label: 'Salin ke Clipboard',
          icon: Icons.copy_outlined,
        ),
        ModernBottomSheetAction(
          label: 'Bagikan via WhatsApp',
          icon: Icons.chat_outlined,
        ),
        ModernBottomSheetAction(
          label: 'Bagikan Lainnya',
          icon: Icons.share_outlined,
        ),
      ],
    );

    if (result == null || !context.mounted) return;

    switch (result) {
      case 0:
        await copyToClipboard(context, text, successMessage: 'Struk berhasil disalin');
        break;
      case 1:
        await shareViaWhatsApp(context, text, phoneNumber: phoneNumber);
        break;
      case 2:
        await shareText(text, subject: subject);
        break;
    }
  }
}
