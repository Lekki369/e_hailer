import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../../core/domain/failures/app_failure.dart';
import '../../../core/presentation/utils/fp_framework.dart';
import '../../delivery/infrastructure/delivery_remote_service.dart';

class DriverLocationBroadcastService {
  final DeliveryRemoteService _deliveryRemoteService;
  StreamSubscription<Either<AppFailure, Unit>>? _positionSubscription;
  DriverLocationBroadcastService({DeliveryRemoteService? deliveryRemoteService})
    : _deliveryRemoteService = deliveryRemoteService ?? DeliveryRemoteService();
  bool get isBroadcasting => _positionSubscription != null;
  Future<Either<AppFailure, Unit>> checkAndRequestPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return left(const LocationServiceDisabledFailure());
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return left(
          const LocationPermissionFailure(
            message:
                'Enable location access in Settings to share your delivery progress.',
          ),
        );
      }
      return right(unit);
    } catch (_) {
      return left(const LocationPermissionFailure());
    }
  }

  Future<Either<AppFailure, Position>> broadcastCurrentLocation(
    String orderId,
  ) async {
    final permission = await checkAndRequestPermission();
    if (permission.isLeft()) {
      return permission.map((_) => throw StateError('Unreachable'));
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final sent = await _deliveryRemoteService.updateDriverLocation(
        orderId: orderId,
        driverLatitude: position.latitude,
        driverLongitude: position.longitude,
      );
      return sent.map((_) => position);
    } catch (_) {
      return left(
        const NetworkFailure(
          message: 'Could not share your current location. Please try again.',
        ),
      );
    }
  }

  Future<Either<AppFailure, Unit>> startLiveBroadcast(
    String orderId, {
    void Function(AppFailure)? onFailure,
  }) async {
    await stopLiveBroadcast();
    final initial = await broadcastCurrentLocation(orderId);
    if (initial.isLeft()) return initial.map((_) => unit);
    try {
      _positionSubscription =
          Geolocator.getPositionStream(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  distanceFilter: 15,
                ),
              )
              .asyncMap(
                (position) => _deliveryRemoteService.updateDriverLocation(
                  orderId: orderId,
                  driverLatitude: position.latitude,
                  driverLongitude: position.longitude,
                ),
              )
              .listen(
                (result) => result.fold((failure) {
                  unawaited(stopLiveBroadcast());
                  onFailure?.call(failure);
                }, (_) {}),
                onError: (_) {
                  unawaited(stopLiveBroadcast());
                  onFailure?.call(
                    const NetworkFailure(
                      message:
                          'Live location sharing stopped. Check your location settings and retry.',
                    ),
                  );
                },
              );
      return right(unit);
    } catch (_) {
      return left(
        const NetworkFailure(message: 'Could not start live location sharing.'),
      );
    }
  }

  Future<void> stopLiveBroadcast() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
  }
}
