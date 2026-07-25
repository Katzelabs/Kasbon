import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for navigation sidebar expanded state
///
/// Shared between ModernAppShell and screens that need to know
/// the navigation sidebar state for responsive layout calculations.
final navigationSidebarExpandedProvider = StateProvider<bool>((ref) => false);
