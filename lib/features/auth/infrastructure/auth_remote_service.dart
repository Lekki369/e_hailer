import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../domain/user_entity.dart';

class AuthRemoteService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRemoteService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  /// Watch user profile document
  Stream<UserEntity?> watchUserProfile(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserEntity.fromMap(doc.data()!, doc.id);
    });
  }

  /// Sign in with email and password
  Future<Either<AppFailure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        return left(const AuthFailure(message: 'Authentication failed.'));
      }

      final doc = await _usersRef.doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return left(const AuthFailure(message: 'User profile not found.'));
      }

      return right(UserEntity.fromMap(doc.data()!, doc.id));
    } on FirebaseAuthException catch (e) {
      return left(AuthFailure(message: e.message ?? 'Authentication error.'));
    } catch (e) {
      return left(ServerFailure(message: 'An unexpected error occurred: $e'));
    }
  }

  /// Create new user profile in Firestore
  Future<Either<AppFailure, UserEntity>> createUserProfile(
      UserEntity user) async {
    try {
      await _usersRef.doc(user.uid).set(user.toMap());
      return right(user);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to create user profile: $e'));
    }
  }

  /// Toggle driver online/availability status
  Future<Either<AppFailure, Unit>> setDriverAvailability({
    required String uid,
    required bool isAvailable,
  }) async {
    try {
      await _usersRef.doc(uid).update({'isAvailable': isAvailable});
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to update availability: $e'));
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
