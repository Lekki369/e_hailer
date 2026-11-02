import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/infrastructure/operations_api.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../domain/entities/wallet_top_up.dart';

class WalletPaymentService {
  final OperationsApi api;
  WalletPaymentService(this.api);

  Future<Either<AppFailure, WalletTopUp?>> _send(
    String command,
    Map<String, dynamic> input,
  ) async {
    final result = await api.execute(command, input);
    return result.fold(left, (value) {
      try {
        final topUp = value['topUp'];
        if (topUp == null && command == 'getWalletTopUp') return right(null);
        return right(
          WalletTopUp.fromMap(Map<String, dynamic>.from(topUp as Map)),
        );
      } catch (_) {
        return left(
          const ServerFailure(
            message: 'The payment status could not be read. Please retry.',
          ),
        );
      }
    });
  }

  Future<Either<AppFailure, WalletTopUp?>> recover() =>
      _send('getWalletTopUp', {});
  Future<Either<AppFailure, WalletTopUp?>> initialize(int amountMinor) =>
      _send('initializeWalletTopUp', {'amountMinor': amountMinor});
  Future<Either<AppFailure, WalletTopUp?>> verify(String reference) =>
      _send('verifyWalletTopUp', {'reference': reference});
}
