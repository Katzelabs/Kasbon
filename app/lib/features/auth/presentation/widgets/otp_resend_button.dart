import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';

/// "Kirim ulang kode", rate-limited by a visible countdown.
///
/// Starts *in* cooldown, because every screen that shows this has just caused
/// a code to be sent - arriving with the button already live invites a second
/// request before the first email has landed, and the server answers that with
/// a rate-limit error the user reads as a bug.
///
/// The countdown is a courtesy, not a control: `[auth.email] max_frequency` on
/// the server is what actually enforces the interval. Keep the two in step.
class OtpResendButton extends StatefulWidget {
  const OtpResendButton({
    super.key,
    required this.onResend,
    this.enabled = true,
    this.cooldown = const Duration(seconds: 60),
  });

  /// Sends a fresh code. Returning false leaves the countdown expired, so the
  /// user can try again immediately rather than waiting out a failed send.
  final Future<bool> Function() onResend;

  final bool enabled;
  final Duration cooldown;

  @override
  State<OtpResendButton> createState() => _OtpResendButtonState();
}

class _OtpResendButtonState extends State<OtpResendButton> {
  Timer? _timer;
  late int _secondsLeft;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = widget.cooldown.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _onPressed() async {
    setState(() => _isSending = true);
    final sent = await widget.onResend();
    if (!mounted) return;
    setState(() => _isSending = false);
    if (sent) _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _secondsLeft > 0;

    if (waiting) {
      return Semantics(
        liveRegion: true,
        child: Text(
          'Kirim ulang kode dalam $_secondsLeft detik',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ModernButton.text(
      onPressed: widget.enabled && !_isSending ? _onPressed : null,
      isLoading: _isSending,
      child: Text(
        'Kirim ulang kode',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
