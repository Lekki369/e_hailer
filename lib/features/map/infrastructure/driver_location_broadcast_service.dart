import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../../core/domain/failures/app_failure.dart';
import '../../../core/presentation/utils/fp_framework.dart';
import '../../delivery/infrastructure/delivery_remote_service.dart';

class DriverLocationBroadcastService {
  final DeliveryRemoteService _deliveryRemoteService;
  StreamSubscription<Position>? _positionSubscription;

  DriverLocationBroadcastService({
    DeliveryRemoteService? deliveryRemoteService,
  }) : _deliveryRemoteService =
            deliveryRemoteService ?? DeliveryRemoteService();

  bool get isBroadcasting => _positionSubscription != null;

  /// Check and request location permissions
  Future<Either<AppFailure, Unit>> checkAndRequestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return left(const LocationServiceDisabledFailure());
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return left(const LocationPermissionFailure());
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return left(const LocationPermissionFailure(
        message: 'Location permissions are permanently denied. Please enable in Settings.',
      ));
    }

    return right(unit);
  }

  /// Broadcast one-time immediate current GPS location to the active order
  Future<Either<AppFailure, Position>> broadcastCurrentLocation(
      String orderId) async {
    final permissionRes = await checkAndRequestPermission();
    if (permissionRes.isLeft()) {
      return left(
          permissionRes.fold((f) => f, (_) => const UnexpectedFailure()));
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _deliveryRemoteService.updateDriverLocation(
        orderId: orderId,
        driverLatitude: position.latitude,
        driverLongitude: position.longitude,
      );

      return right(position);
    } catch (e) {
      return left(ServerFailure(message: 'Failed to broadcast GPS: $e'));
    }
  }

  /// Start continuous live GPS broadcasting for an ongoing delivery trip
  Future<Either<AppFailure, Unit>> startLiveBroadcast(String orderId) async {
    final permissionRes = await checkAndRequestPermission();
    if (permissionRes.isLeft()) {
      return left(
          permissionRes.fold((f) => f, (_) => const UnexpectedFailure()));
    }

    await stopLiveBroadcast();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15, // Update every 15 meters
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((position) {
      _deliveryRemoteService.updateDriverLocation(
        orderId: orderId,
        driverLatitude: position.latitude,
        driverLongitude: position.longitude,
      );
    });

    return right(unit);
  }

  /// Stop continuous GPS broadcasting
  Future<void> stopLiveBroadcast() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
