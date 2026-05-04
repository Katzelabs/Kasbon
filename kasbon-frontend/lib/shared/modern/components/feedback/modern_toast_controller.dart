import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../utils/modern_variants.dart';
import 'modern_toast_card.dart';

/// Maximum number of toasts visible simultaneously.
const int _kMaxStack = 5;

/// Single toast item managed by [ToastController].
@immutable
class ToastEntry {
  const ToastEntry({
    required this.id,
    required this.message,
    required this.variant,
    required this.duration,
  });

  final int id;
  final String message;
  final ModernToastVariant variant;
  final Duration duration;
}

/// Global controller that owns the live toast stack and renders it via a
/// single root [OverlayEntry] inserted into the root Navigator's [Overlay].
///
/// Inserting the entry directly into the root overlay (instead of pushing a
/// route) places it above all navigator routes, including dialogs and modal
/// bottom sheets — which is the requirement for [ModernToast].
class ToastController extends ChangeNotifier {
  ToastController._();

  static final ToastController instance = ToastController._();

  final List<ToastEntry> _entries = <ToastEntry>[];
  final List<ToastEntry> _pending = <ToastEntry>[];
  OverlayEntry? _hostEntry;
  int _nextId = 0;

  /// Read-only view of active toasts (newest first).
  List<ToastEntry> get entries => List.unmodifiable(_entries);

  /// Pushes a new toast onto the stack. If the root overlay is not yet
  /// available (e.g. during app startup), the toast is buffered and flushed
  /// once the overlay can be resolved.
  void push({
    required String message,
    required ModernToastVariant variant,
    Duration duration = const Duration(seconds: 3),
  }) {
    final entry = ToastEntry(
      id: _nextId++,
      message: message,
      variant: variant,
      duration: duration,
    );

    final overlay = _resolveOverlay();
    if (overlay == null) {
      _pending.add(entry);
      return;
    }

    _flushPending(overlay);
    _insertEntry(entry, overlay);
  }

  /// Removes the toast with [id]. No-op if it has already been removed.
  /// Called by [ToastCard] after its exit animation finishes.
  void dismiss(int id) {
    final removed = _entries.indexWhere((e) => e.id == id);
    if (removed == -1) return;

    _entries.removeAt(removed);

    if (_entries.isEmpty) {
      _removeHost();
    } else {
      _hostEntry?.markNeedsBuild();
    }
    notifyListeners();
  }

  /// Removes every active toast immediately (no exit animation).
  void clear() {
    _entries.clear();
    _removeHost();
    notifyListeners();
  }

  void _insertEntry(ToastEntry entry, OverlayState overlay) {
    if (_entries.length >= _kMaxStack) {
      _entries.removeLast();
    }
    _entries.insert(0, entry);

    if (_hostEntry == null) {
      _hostEntry = OverlayEntry(builder: _buildHost);
      overlay.insert(_hostEntry!);
    } else {
      _hostEntry!.markNeedsBuild();
    }
    notifyListeners();
  }

  void _flushPending(OverlayState overlay) {
    if (_pending.isEmpty) return;
    final pending = List<ToastEntry>.from(_pending);
    _pending.clear();
    for (final entry in pending) {
      _insertEntry(entry, overlay);
    }
  }

  void _removeHost() {
    _hostEntry?.remove();
    _hostEntry = null;
  }

  OverlayState? _resolveOverlay() {
    return AppRouter.rootNavigatorKey.currentState?.overlay;
  }

  Widget _buildHost(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxWidth = math.min(mediaQuery.size.width - 32, 360.0);

    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: AnimatedBuilder(
            animation: this,
            builder: (context, _) {
              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final entry in _entries) ...[
                      ToastCard(
                        key: ValueKey(entry.id),
                        entry: entry,
                        onDismiss: () => dismiss(entry.id),
                      ),
                      const SizedBox(height: AppDimensions.spacing8),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
