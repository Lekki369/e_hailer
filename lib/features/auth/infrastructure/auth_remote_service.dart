import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../../delivery/domain/value_objects/delivery_type.dart';
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

  /// Sign up a new user with email and password and initialize Firestore profile
  Future<Either<AppFailure, UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
    VehicleType? vehicleType,
    String? vehiclePlateNumber,
    String? vehicleModel,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        return left(const AuthFailure(message: 'Registration failed.'));
      }

      final newUser = UserEntity(
        uid: uid,
        role: role,
        fullName: fullName.trim(),
        email: email.trim(),
        phone: phone.trim(),
        walletBalance: 0.0,
        rating: 5.0,
        isAvailable: role == UserRole.driver,
        vehicleType:
            role == UserRole.driver ? (vehicleType ?? VehicleType.bike) : null,
        vehiclePlateNumber:
            role == UserRole.driver ? vehiclePlateNumber?.trim() : null,
        vehicleModel: role == UserRole.driver ? vehicleModel?.trim() : null,
        createdAt: DateTime.now(),
      );

      final saveResult = await createUserProfile(newUser);
      return saveResult;
    } on FirebaseAuthException catch (e) {
      return left(AuthFailure(message: e.message ?? 'Registration error.'));
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

  /// Update user profile details and driver vehicle settings
  Future<Either<AppFailure, Unit>> updateUserProfile({
    required String uid,
    String? fullName,
    String? phone,
    UserRole? role,
    VehicleType? vehicleType,
    String? vehiclePlateNumber,
    String? vehicleModel,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (fullName != null) updateData['fullName'] = fullName.trim();
      if (phone != null) updateData['phone'] = phone.trim();
      if (role != null) updateData['role'] = role.name;
      if (vehicleType != null) updateData['vehicleType'] = vehicleType.name;
      if (vehiclePlateNumber != null) {
        updateData['vehiclePlateNumber'] = vehiclePlateNumber.trim();
      }
      if (vehicleModel != null) {
        updateData['vehicleModel'] = vehicleModel.trim();
      }

      if (updateData.isNotEmpty) {
        await _usersRef.doc(uid).update(updateData);
      }
      return right(unit);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to update profile: $e'));
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
