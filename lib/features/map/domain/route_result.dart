import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

class RouteResult extends Equatable {
  final double distanceKm;
  final int durationMinutes;
  final List<LatLng> points;

  const RouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.points,
  });

  @override
  List<Object?> get props => [distanceKm, durationMinutes, points];
}
