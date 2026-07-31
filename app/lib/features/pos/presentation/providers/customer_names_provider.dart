import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../../transactions/domain/usecases/get_customer_names.dart';

/// Customer names this shop has used before, most recently first.
///
/// Fetched once per dialog and filtered on the client as the cashier types.
/// The whole list is a handful of strings - a warung has regulars, not a CRM -
/// so a query per keystroke would spend a slow connection narrowing something
/// already in memory.
///
/// Failures collapse to an empty list rather than surfacing. The autocomplete
/// is a convenience over a plain text field: if the names cannot be loaded the
/// cashier types the name, which is what they did before this existed. An error
/// state here would interrupt a sale to report that a hint is missing.
final customerNamesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final result = await getIt<GetCustomerNames>()(
    const GetCustomerNamesParams(),
  );

  return result.fold((_) => const <String>[], (names) => names);
});
