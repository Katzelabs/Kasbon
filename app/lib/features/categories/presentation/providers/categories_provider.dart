import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injection.dart';
import '../../domain/entities/category.dart';
import '../../domain/usecases/get_all_categories.dart';

/// Provider for all categories
final categoriesProvider =
    FutureProvider.autoDispose<List<Category>>((ref) async {
  final useCase = getIt<GetAllCategories>();
  final result = await useCase();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (categories) => categories,
  );
});
