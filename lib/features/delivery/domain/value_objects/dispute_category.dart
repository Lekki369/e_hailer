/// Categorization of delivery disputes, damage claims, and operational exceptions
enum DisputeCategory {
  damagedItem('Damaged Package / Contents'),
  missingItem('Missing / Incomplete Shipment'),
  unreachableRecipient('Recipient Unreachable (Driver Failure)'),
  wrongAddress('Incorrect or Inaccessible Address'),
  fareDispute('Overcharged / Fare Discrepancy'),
  driverMisconduct('Driver Misconduct / Undue Delay'),
  packageRefused('Recipient Refused Handover'),
  other('Other Operational Incident');

  final String label;
  const DisputeCategory(this.label);

  static DisputeCategory fromString(String? value) {
    return DisputeCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => DisputeCategory.other,
    );
  }
}
