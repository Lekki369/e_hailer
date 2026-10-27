import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/entities/payout_request.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/value_objects/payout_status.dart';
import '../../infrastructure/wallet_remote_service.dart';

/// Provider for Wallet Remote Service
final walletRemoteServiceProvider = Provider<WalletRemoteService>((ref) {
  return WalletRemoteService();
});

/// Stream provider for user's transaction ledger
final userTransactionsStreamProvider =
    StreamProvider.family<List<WalletTransaction>, String>((ref, userId) {
  final service = ref.watch(walletRemoteServiceProvider);
  return service.watchUserTransactions(userId);
});

/// Notifier for filtering payout requests in admin console (null = all)
class PayoutStatusFilterNotifier extends Notifier<PayoutStatus?> {
  @override
  PayoutStatus? build() => null;

  @override
  set state(PayoutStatus? value) => super.state = value;
}

/// Provider for filtering payout requests in admin console (null = all)
final payoutStatusFilterProvider =
    NotifierProvider<PayoutStatusFilterNotifier, PayoutStatus?>(
  PayoutStatusFilterNotifier.new,
);

/// Stream provider of all platform payout requests (for Operations / Admin)
final allPayoutRequestsStreamProvider =
    StreamProvider<List<PayoutRequest>>((ref) {
  final service = ref.watch(walletRemoteServiceProvider);
  final filter = ref.watch(payoutStatusFilterProvider);
  return service.watchAllPayoutRequests(statusFilter: filter);
});

/// Stream provider for a specific driver's payout history
final driverPayoutRequestsStreamProvider =
    StreamProvider.family<List<PayoutRequest>, String>((ref, driverId) {
  final service = ref.watch(walletRemoteServiceProvider);
  return service.watchDriverPayoutRequests(driverId);
});

/// Count of pending payouts awaiting admin review
final pendingPayoutCountProvider = Provider<int>((ref) {
  final payoutsAsync = ref.watch(allPayoutRequestsStreamProvider);
  return payoutsAsync.maybeWhen(
    data: (payouts) =>
        payouts.where((p) => p.status == PayoutStatus.pending).length,
    orElse: () => 0,
  );
});
