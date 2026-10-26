import 'package:equatable/equatable.dart';

sealed class AppFailure extends Equatable {
  final String message;
  const AppFailure(this.message);

  @override
  List<Object?> get props => [message];
}

final class ServerFailure extends AppFailure {
  final int? code;
  const ServerFailure({required String message, this.code}) : super(message);

  @override
  List<Object?> get props => [message, code];
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    String message = 'No internet connection detected.',
  }) : super(message);
}

final class AuthFailure extends AppFailure {
  const AuthFailure({required String message}) : super(message);
}

final class LocationPermissionFailure extends AppFailure {
  const LocationPermissionFailure({
    String message = 'Location permission is denied.',
  }) : super(message);
}

final class LocationServiceDisabledFailure extends AppFailure {
  const LocationServiceDisabledFailure({
    String message = 'Location services are disabled on this device.',
  }) : super(message);
}

final class OrderNotFoundFailure extends AppFailure {
  const OrderNotFoundFailure({
    String message = 'Delivery order not found.',
  }) : super(message);
}

final class InvalidOtpFailure extends AppFailure {
  const InvalidOtpFailure({
    String message = 'Invalid 4-digit handover verification PIN.',
  }) : super(message);
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({
    String message = 'An unexpected error occurred.',
  }) : super(message);
}
