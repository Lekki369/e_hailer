import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../infrastructure/operations_api.dart';
import '../../../features/auth/presentation/providers/auth_providers.dart';

final operationsApiProvider = Provider<OperationsApi>((ref) {
  // Discard pending request keys and connections when the account changes.
  ref.watch(authStateProvider.select((state) => state.value?.uid));
  final api = OperationsApi();
  ref.onDispose(api.dispose);
  return api;
});
