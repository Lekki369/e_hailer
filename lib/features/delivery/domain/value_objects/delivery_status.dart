enum DeliveryStatus {
  created('Order Placed'),
  searchingDriver('Finding Nearby Driver'),
  assigned('Driver Assigned'),
  arrivedPickup('Driver Arrived at Pickup'),
  pickedUp('Package Picked Up'),
  inTransit('In Transit to Destination'),
  arrivedDropoff('Arrived at Destination'),
  delivered('Delivered'),
  cancelled('Cancelled');

  final String label;
  const DeliveryStatus(this.label);

  bool get isOngoing =>
      this != DeliveryStatus.delivered && this != DeliveryStatus.cancelled;

  bool get isCompleted => this == DeliveryStatus.delivered;
  bool get isCancelled => this == DeliveryStatus.cancelled;
}
