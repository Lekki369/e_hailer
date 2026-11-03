import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/domain/failures/app_failure.dart';
import '../../../../core/presentation/utils/fp_framework.dart';
import '../../delivery/domain/value_objects/delivery_type.dart';
import '../domain/user_entity.dart';

class AuthRemoteService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRemoteService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
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
        password: password,
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
      return left(
        ServerFailure(
          message: 'An unexpected error occurred. Please try again.',
        ),
      );
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
    if (role.isStaff) {
      return left(
        const UnauthorizedActionFailure(
          message: 'Staff accounts are provisioned by an administrator.',
        ),
      );
    }
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
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
        isAvailable: false,
        vehicleType: role == UserRole.driver
            ? (vehicleType ?? VehicleType.bike)
            : null,
        vehiclePlateNumber: role == UserRole.driver
            ? vehiclePlateNumber?.trim()
            : null,
        vehicleModel: role == UserRole.driver ? vehicleModel?.trim() : null,
        createdAt: DateTime.now(),
      );

      final saveResult = await createUserProfile(newUser);
      return saveResult;
    } on FirebaseAuthException catch (e) {
      return left(AuthFailure(message: e.message ?? 'Registration error.'));
    } catch (e) {
      return left(
        ServerFailure(
          message: 'An unexpected error occurred. Please try again.',
        ),
      );
    }
  }

  /// Create new user profile in Firestore
  Future<Either<AppFailure, UserEntity>> createUserProfile(
    UserEntity user,
  ) async {
    try {
      await _usersRef.doc(user.uid).set(user.toMap());
      return right(user);
    } catch (e) {
      return left(
        ServerFailure(
          message: 'Failed to create user profile. Please try again.',
        ),
      );
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
      return left(
        ServerFailure(
          message: 'Failed to update availability. Please try again.',
        ),
      );
    }
  }

  /// Update user profile details and driver vehicle settings
  Future<Either<AppFailure, Unit>> updateUserProfile({
    required String uid,
    String? fullName,
    String? phone,
    VehicleType? vehicleType,
    String? vehiclePlateNumber,
    String? vehicleModel,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (fullName != null) updateData['fullName'] = fullName.trim();
      if (phone != null) updateData['phone'] = phone.trim();
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
      return left(
        ServerFailure(message: 'Failed to update profile. Please try again.'),
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Send password reset instructions without revealing account existence.
  Future<Either<AppFailure, String>> sendPasswordReset({
    required String identifier,
  }) async {
    final email = identifier.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return left(
        const AuthFailure(
          message:
              'Enter your registered email address. For a phone-only account, use SMS sign-in.',
        ),
      );
    }
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return right(email);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') return right(email);
      return left(
        const AuthFailure(
          message:
              'Could not send reset instructions. Check your email and try again later.',
        ),
      );
    } catch (_) {
      return left(
        const NetworkFailure(message: 'Check your connection and try again.'),
      );
    }
  }

  /// Send SMS OTP verification code to a phone number
  Future<Either<AppFailure, String>> sendPhoneOtp({
    required String phoneNumber,
    int? resendToken,
  }) async {
    final completer = Completer<Either<AppFailure, String>>();

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber.trim(),
        forceResendingToken: resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Instant auto-retrieval (primarily Android)
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.complete(
              left(
                AuthFailure(message: e.message ?? 'Phone verification failed.'),
              ),
            );
          }
        },
        codeSent: (String verificationId, int? token) {
          if (!completer.isCompleted) {
            completer.complete(right(verificationId));
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!completer.isCompleted) completer.complete(right(verificationId));
        },
      );
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete(
          left(
            ServerFailure(
              message:
                  'Failed to initiate phone verification. Please try again.',
            ),
          ),
        );
      }
    }

    return completer.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => left(
        const AuthFailure(
          message: 'SMS verification timed out. Please try again.',
        ),
      ),
    );
  }

  /// Verify SMS OTP code and sign in or initialize profile for user
  Future<Either<AppFailure, UserEntity>> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
    UserRole role = UserRole.customer,
  }) async {
    if (role.isStaff) {
      return left(
        const UnauthorizedActionFailure(
          message: 'Staff accounts are provisioned by an administrator.',
        ),
      );
    }
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final uid = userCredential.user?.uid;
      if (uid == null) {
        return left(const AuthFailure(message: 'Phone sign-in failed.'));
      }

      final doc = await _usersRef.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return right(UserEntity.fromMap(doc.data()!, doc.id));
      }

      // First-time phone sign in: create initial user profile in Firestore
      final shortSuffix = phoneNumber.length > 4
          ? phoneNumber.substring(phoneNumber.length - 4)
          : '';
      final newUser = UserEntity(
        uid: uid,
        role: role,
        fullName: 'User $shortSuffix',
        email: userCredential.user?.email ?? '',
        phone: phoneNumber.trim(),
        walletBalance: 0.0,
        rating: 5.0,
        createdAt: DateTime.now(),
      );

      return await createUserProfile(newUser);
    } on FirebaseAuthException catch (e) {
      return left(AuthFailure(message: e.message ?? 'Invalid OTP code.'));
    } catch (e) {
      return left(
        ServerFailure(message: 'Verification failed. Please try again.'),
      );
    }
  }
}
