enum DeliveryType {
  /// Point-to-point on-demand express courier / dispatch hailing (from MyOGA & Deliverzler)
  express('Express On-Demand'),

  /// Scheduled multi-hop hub courier shipment with dimensional volumetric weight (from courierManagementSystem)
  consignment('Standard Consignment');

  final String label;
  const DeliveryType(this.label);
}

enum VehicleType {
  bike('Motorcycle / Bike', 1.0),
  car('Sedan / Hatchback', 1.5),
  van('Cargo Van', 2.2),
  truck('Heavy Truck', 3.5);

  final String label;
  final double rateMultiplier;
  const VehicleType(this.label, this.rateMultiplier);

  static VehicleType fromString(String? value) {
    return VehicleType.values.firstWhere(
      (e) => e.name.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => VehicleType.bike,
    );
  }
}
