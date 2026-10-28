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

  /// Validates whether an operational state transition to [nextStatus] is legal.
  bool canTransitionTo(DeliveryStatus nextStatus, {bool isAdmin = false}) {
    if (this == nextStatus) return true;

    // Admin override for exceptional hub intervention
    if (isAdmin) {
      if (nextStatus == DeliveryStatus.cancelled) return true;
      if (nextStatus == DeliveryStatus.returnedToHub) return true;
      if (nextStatus == DeliveryStatus.assigned) return true;
      if (nextStatus == DeliveryStatus.searchingDriver) return true;
    }

    switch (this) {
      case DeliveryStatus.created:
        return nextStatus == DeliveryStatus.searchingDriver ||
            nextStatus == DeliveryStatus.assigned ||
            nextStatus == DeliveryStatus.cancelled;

      case DeliveryStatus.searchingDriver:
        return nextStatus == DeliveryStatus.assigned ||
            nextStatus == DeliveryStatus.cancelled;

      case DeliveryStatus.assigned:
        return nextStatus == DeliveryStatus.arrivedPickup ||
            nextStatus == DeliveryStatus.searchingDriver ||
            nextStatus == DeliveryStatus.cancelled;

      case DeliveryStatus.arrivedPickup:
        return nextStatus == DeliveryStatus.pickedUp ||
            nextStatus == DeliveryStatus.inTransit ||
            nextStatus == DeliveryStatus.failedDelivery ||
            nextStatus == DeliveryStatus.cancelled;

      case DeliveryStatus.pickedUp:
        return nextStatus == DeliveryStatus.inTransit ||
            nextStatus == DeliveryStatus.arrivedDropoff ||
            nextStatus == DeliveryStatus.failedDelivery;

      case DeliveryStatus.inTransit:
        return nextStatus == DeliveryStatus.arrivedDropoff ||
            nextStatus == DeliveryStatus.delivered ||
            nextStatus == DeliveryStatus.failedDelivery;

      case DeliveryStatus.arrivedDropoff:
        return nextStatus == DeliveryStatus.delivered ||
            nextStatus == DeliveryStatus.failedDelivery;

      case DeliveryStatus.failedDelivery:
        return nextStatus == DeliveryStatus.returnedToHub ||
            nextStatus == DeliveryStatus.assigned;

      case DeliveryStatus.returnedToHub:
      case DeliveryStatus.delivered:
      case DeliveryStatus.cancelled:
        // Terminal states cannot transition further
        return false;
    }
  }

  static DeliveryStatus fromString(String? value) {
    return DeliveryStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => DeliveryStatus.created,
    );
  }
}
