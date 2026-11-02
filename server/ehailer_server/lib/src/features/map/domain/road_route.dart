import 'package:equatable/equatable.dart';
import '../../../core/domain/operation_failure.dart';

class RoadRoute extends Equatable {
  final double distanceKm;
  final int durationMinutes;
  const RoadRoute(this.distanceKm, this.durationMinutes);
  @override
  List<Object?> get props => [distanceKm, durationMinutes];
}

typedef RouteLookup = Future<RoadRoute> Function(Json pickup, Json dropoff);
