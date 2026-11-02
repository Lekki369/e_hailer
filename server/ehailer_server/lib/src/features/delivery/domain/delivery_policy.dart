import 'dart:math' as math;
import '../../../core/domain/operation_failure.dart';

abstract class DeliveryPolicy {
  static const terminal = {'delivered', 'cancelled', 'returnedToHub'};
  static const transitions = {
    'created': {'searchingDriver', 'assigned', 'cancelled'},
    'searchingDriver': {'assigned', 'cancelled'},
    'assigned': {'arrivedPickup', 'searchingDriver', 'cancelled'},
    'arrivedPickup': {'pickedUp', 'inTransit', 'failedDelivery', 'cancelled'},
    'pickedUp': {'inTransit', 'arrivedDropoff', 'failedDelivery'},
    'inTransit': {'arrivedDropoff', 'delivered', 'failedDelivery'},
    'arrivedDropoff': {'delivered', 'failedDelivery'},
    'failedDelivery': {'returnedToHub', 'assigned'},
  };
  static bool canTransition(String from, String to, {bool admin = false}) {
    if (terminal.contains(from)) return false;
    if (admin &&
        {
          'cancelled',
          'returnedToHub',
          'assigned',
          'searchingDriver',
        }.contains(to)) {
      return true;
    }
    return transitions[from]?.contains(to) ?? false;
  }

  static Json location(dynamic value) {
    requireCondition(value is Map<String, dynamic>, 'Choose a location.');
    final input = value as Json;
    return {
      'latitude': finiteNumber(input['latitude'], -90, 90, 'latitude'),
      'longitude': finiteNumber(input['longitude'], -180, 180, 'longitude'),
      'address': requiredText(input['address'], 'Address'),
      'contactName': requiredText(input['contactName'], 'Contact name', 100),
      'contactPhone': requiredText(input['contactPhone'], 'Contact phone', 30),
    };
  }

  static Json parcel(dynamic value) {
    requireCondition(
      value is Map<String, dynamic>,
      'Parcel details are required.',
    );
    final input = value as Json;
    final quantity = finiteNumber(input['quantity'] ?? 1, 1, 1000, 'quantity');
    requireCondition(
      quantity == quantity.round(),
      'Quantity must be a whole number.',
    );
    const dimensions = ['lengthCm', 'widthCm', 'heightCm'];
    final hasDimensions = dimensions.any((key) => input[key] != null);
    return {
      'category': requiredText(input['category'], 'Parcel category', 50),
      'weightKg': finiteNumber(input['weightKg'], 0.01, 10000, 'parcel weight'),
      'quantity': quantity.toInt(),
      'isFragile': input['isFragile'] == true,
      'description': (input['description'] as String? ?? '').trim().substring(
        0,
        math.min((input['description'] as String? ?? '').trim().length, 500),
      ),
      for (final key in dimensions)
        key: hasDimensions ? finiteNumber(input[key], 0.01, 10000, key) : null,
    };
  }

  static Json pricing(
    double distanceKm,
    Json parcel,
    String vehicle,
    String method,
  ) {
    finiteNumber(distanceKm, 0.01, 5000, 'distance');
    const multipliers = {'bike': 1.0, 'car': 1.5, 'van': 2.2, 'truck': 3.5};
    requireCondition(
      multipliers.containsKey(vehicle),
      'Choose a valid vehicle.',
    );
    requireCondition(
      {'wallet', 'cashOnDelivery'}.contains(method),
      'Card payments are not configured.',
      'payment-unavailable',
    );
    final volumetric = parcel['lengthCm'] == null
        ? 0.0
        : (parcel['lengthCm'] as num) *
              (parcel['widthCm'] as num) *
              (parcel['heightCm'] as num) *
              (parcel['quantity'] as num) /
              5000;
    final base = 500 * multipliers[vehicle]!;
    final distanceFare = (distanceKm * 12000).round() / 100;
    final surcharge =
        (math.max(0, math.max(parcel['weightKg'] as num, volumetric) - 2) *
                    8000 +
                (parcel['isFragile'] == true ? 30000 : 0))
            .round() /
        100;
    final totalMinor = ((base + distanceFare + surcharge) / 10).round() * 1000;
    final commission = (totalMinor * 0.2).round();
    return {
      'baseFare': base,
      'distanceFare': distanceFare,
      'weightSurcharge': surcharge,
      'totalFare': totalMinor / 100,
      'currency': 'NGN',
      'paymentMethod': method,
      'isPaid': method == 'wallet',
      'driverEarnings': (totalMinor - commission) / 100,
      'platformCommission': commission / 100,
    };
  }

  static Json publicTracking(Json order, [Json? previous]) {
    final timeline = List<dynamic>.from(previous?['timeline'] as List? ?? []);
    if (timeline.isEmpty || timeline.last['status'] != order['status']) {
      timeline.add({
        'status': order['status'],
        'timestamp': order['updatedAt'],
      });
    }
    return {
      for (final key in [
        'trackingNumber',
        'status',
        'type',
        'vehicleType',
        'estimatedDurationMinutes',
        'createdAt',
        'updatedAt',
      ])
        key: order[key],
      'timeline': timeline.skip(math.max(0, timeline.length - 30)).toList(),
    };
  }
}
