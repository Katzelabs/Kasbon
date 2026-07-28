import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard shortcuts for the till.
///
/// ## Why a raw key handler rather than Shortcuts/Actions
///
/// Three of these bindings collide with typing. `/` is a character. `Escape`
/// closes an autocomplete. `Ctrl+Backspace` deletes the previous word, which a
/// cashier correcting a mistyped product name will use and expect - and which,
/// bound globally, would empty their cart instead.
///
/// `Shortcuts` sits above the focused widget and cannot ask what has focus, so
/// it fires either way. A [Focus] node with an `onKeyEvent` is on the bubble
/// path: it sees the event only after the focused widget declined it, and it
/// can check what that widget was. So the conflicting bindings are suppressed
/// while a text field has focus and the safe ones - `F2`, `Ctrl+Enter` - are
/// not.
///
/// ## Not gated on platform
///
/// There is no `isPointerFirst` check here. A tablet with a Bluetooth keyboard
/// is exactly the setup a busy counter uses, and gating this on desktop would
/// take the shortcuts away from it. On a device with no keyboard the node
/// simply never receives a key event.
class PosShortcuts extends StatelessWidget {
  const PosShortcuts({
    super.key,
    required this.child,
    this.onFocusSearch,
    this.onCheckout,
    this.onClearCart,
    this.onDismiss,
  });

  final Widget child;

  /// `/` or `Ctrl+F` - move focus to the product search field.
  final VoidCallback? onFocusSearch;

  /// `F2` or `Ctrl+Enter` - open the payment dialog.
  final VoidCallback? onCheckout;

  /// `Ctrl+Backspace` - empty the cart. Confirmed by the caller, not here.
  final VoidCallback? onClearCart;

  /// `Escape` - back out of whatever is open.
  final VoidCallback? onDismiss;

  /// Whether the focused widget is a text field.
  ///
  /// The primary focus of a `TextField` is the `EditableText`'s node, whose
  /// context is the `EditableText` element itself; the ancestor lookup covers
  /// the wrappers that install their own node above it.
  static bool _isTypingContext() {
    final focused = FocusManager.instance.primaryFocus;
    final context = focused?.context;
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final isControlHeld = keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        // A Mac cashier reaches for Cmd, and the muscle memory is the same.
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);

    final key = event.logicalKey;
    final isTyping = _isTypingContext();

    // Checkout: safe while typing, because neither activator produces text.
    if (onCheckout != null) {
      if (key == LogicalKeyboardKey.f2) {
        onCheckout!();
        return KeyEventResult.handled;
      }
      if (isControlHeld &&
          (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter)) {
        onCheckout!();
        return KeyEventResult.handled;
      }
    }

    // Focus search. Ctrl+F works anywhere; a bare slash is a character, so it
    // only counts where a character would go nowhere.
    if (onFocusSearch != null) {
      if (isControlHeld && key == LogicalKeyboardKey.keyF) {
        onFocusSearch!();
        return KeyEventResult.handled;
      }
      if (!isTyping && !isControlHeld && key == LogicalKeyboardKey.slash) {
        onFocusSearch!();
        return KeyEventResult.handled;
      }
    }

    // Clear cart. Ctrl+Backspace is delete-previous-word in a text field, so
    // this yields there rather than emptying the cart mid-correction.
    if (onClearCart != null &&
        !isTyping &&
        isControlHeld &&
        key == LogicalKeyboardKey.backspace) {
      onClearCart!();
      return KeyEventResult.handled;
    }

    // Escape. A text field with focus gets first refusal - it may be closing
    // its own suggestion list - and this only sees the event if it declined.
    if (onDismiss != null && key == LogicalKeyboardKey.escape) {
      onDismiss!();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Autofocus so the node is in the focus chain before anything inside has
      // been touched; without it the first keystroke on a freshly-opened
      // screen goes to the root and is dropped.
      autofocus: true,
      // Skipped by Tab: this node exists to listen, not to be landed on.
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: child,
    );
  }
}
