import '../../../core/domain/operation_failure.dart';

/// Stable 0.1-degree cells. Approval covers the selected cell and its eight
/// neighbours; exact customer locations never enter a job preview.
abstract class DriverAccessPolicy {
  static String area(num latitude, num longitude) =>
      '${(latitude * 10).floor()}:${(longitude * 10).floor()}';

  static List<String> areas(num latitude, num longitude) => [
    for (var dy = -1; dy <= 1; dy++)
      for (var dx = -1; dx <= 1; dx++)
        '${(latitude * 10).floor() + dy}:${(longitude * 10).floor() + dx}',
  ];

  static bool eligible(Json driver, Json order) {
    final pickup = order['pickupLocation'] as Map;
    return driver['role'] == 'driver' &&
        driver['driverApproved'] == true &&
        driver['vehicleType'] == order['vehicleType'] &&
        ((driver['serviceAreaIds'] as List?) ?? []).contains(
          area(pickup['latitude'] as num, pickup['longitude'] as num),
        );
  }

  static Json previewLocation(Map point) => {
    'latitude': ((point['latitude'] as num) * 10).floor() / 10 + 0.05,
    'longitude': ((point['longitude'] as num) * 10).floor() / 10 + 0.05,
    'address': 'Approximate area — exact address after assignment',
    'contactName': '',
    'contactPhone': '',
  };
}
