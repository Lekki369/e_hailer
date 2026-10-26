enum DeliveryStatus {
  created('Order Placed'),
  searchingDriver('Finding Nearby Driver'),
  assigned('Driver Assigned'),
  arrivedPickup('Driver Arrived at Pickup'),
  pickedUp('Package Picked Up'),
  inTransit('In Transit to Destination'),
  arrivedDropoff('Arrived at Destination'),
  delivered('Delivered'),
  failedDelivery('Delivery Failed'),
  returnedToHub('Returned to Hub'),
  cancelled('Cancelled');

  final String label;
  const DeliveryStatus(this.label);

  bool get isOngoing =>
      this != DeliveryStatus.delivered &&
      this != DeliveryStatus.cancelled &&
      this != DeliveryStatus.failedDelivery &&
      this != DeliveryStatus.returnedToHub;

  bool get isCompleted => this == DeliveryStatus.delivered;
  bool get isCancelled => this == DeliveryStatus.cancelled;
  bool get isFailed =>
      this == DeliveryStatus.failedDelivery ||
      this == DeliveryStatus.returnedToHub;

  static DeliveryStatus fromString(String? value) {
    return DeliveryStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => DeliveryStatus.created,
    );
  }
}
