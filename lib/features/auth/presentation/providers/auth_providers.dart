import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../domain/user_entity.dart';
import '../../infrastructure/auth_remote_service.dart';

final authRemoteServiceProvider = Provider<AuthRemoteService>((ref) {
  return AuthRemoteService();
});

/// Stream of the current FirebaseAuth state (logged in vs logged out)
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRemoteServiceProvider).authStateChanges;
});

/// Stream of the current authenticated user's Firestore profile (Role, Wallet, etc.)
final currentUserProfileProvider = StreamProvider<UserEntity?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) {
    return Stream.value(null);
  }
  return ref.watch(authRemoteServiceProvider).watchUserProfile(authUser.uid);
});
