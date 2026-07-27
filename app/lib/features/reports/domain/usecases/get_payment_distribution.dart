import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/payment_slice.dart';
import '../repositories/analytics_repository.dart';
import 'get_profit_summary.dart';

/// Use case to get the transaction breakdown by payment method.
///
/// Takes a plain date range: filtering this report by payment method would
/// reduce it to a single slice.
class GetPaymentDistribution
    extends UseCase<List<PaymentSlice>, DateRangeParams> {
  final AnalyticsRepository repository;

  GetPaymentDistribution(this.repository);

  @override
  Future<Either<Failure, List<PaymentSlice>>> call(
      DateRangeParams params) async {
    return await repository.getPaymentDistribution(
      from: params.from,
      to: params.to,
    );
  }
}
