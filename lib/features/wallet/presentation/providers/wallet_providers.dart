import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../domain/entities/wallet_transaction.dart';
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
