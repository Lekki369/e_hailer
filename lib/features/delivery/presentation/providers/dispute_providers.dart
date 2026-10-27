import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/entities/delivery_dispute.dart';
import '../../domain/value_objects/dispute_status.dart';
import '../../infrastructure/dispute_remote_service.dart';

/// Provider for Dispute Remote Service
final disputeRemoteServiceProvider = Provider<DisputeRemoteService>((ref) {
  return DisputeRemoteService();
});

/// Stream provider for all disputes across the platform
final allDisputesStreamProvider = StreamProvider<List<DeliveryDispute>>((ref) {
  final service = ref.watch(disputeRemoteServiceProvider);
  return service.watchAllDisputes();
});

/// Stream provider for disputes associated with a specific order
final orderDisputesStreamProvider =
    StreamProvider.family<List<DeliveryDispute>, String>((ref, orderId) {
  final service = ref.watch(disputeRemoteServiceProvider);
  return service.watchDisputesForOrder(orderId);
});

/// Notifier for disputes management status filter
class DisputeStatusFilterNotifier extends Notifier<DisputeStatus?> {
  @override
  DisputeStatus? build() => null;

  @override
  set state(DisputeStatus? value) => super.state = value;
}

/// Filter state for disputes management
final disputeStatusFilterProvider =
    NotifierProvider<DisputeStatusFilterNotifier, DisputeStatus?>(
  DisputeStatusFilterNotifier.new,
);

/// Filtered disputes provider
final filteredDisputesProvider = Provider<AsyncValue<List<DeliveryDispute>>>((ref) {
  final allDisputesAsync = ref.watch(allDisputesStreamProvider);
  final filter = ref.watch(disputeStatusFilterProvider);

  return allDisputesAsync.whenData((disputes) {
    if (filter == null) return disputes;
    return disputes.where((d) => d.status == filter).toList();
  });
});

/// Count of active pending disputes awaiting review
final pendingDisputeCountProvider = Provider<int>((ref) {
  final allDisputesAsync = ref.watch(allDisputesStreamProvider);
  return allDisputesAsync.maybeWhen(
    data: (disputes) => disputes.where((d) => d.status.isPending).length,
    orElse: () => 0,
  );
});
