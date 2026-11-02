/// Categorization of delivery disputes, damage claims, and operational exceptions
enum DisputeCategory {
  damagedItem('Damaged Package / Contents'),
  lateDelivery('Late Delivery / Undue Delay'),
  wrongItem('Wrong Item / Shipment Mismatch'),
  noShow('Recipient / Driver No-Show'),
  riderBehavior('Rider Misconduct / Behavior'),
  driverMisconduct('Driver Misconduct / Undue Delay'),
  paymentIssue('Fare / Payment Discrepancy'),
  fareDispute('Overcharged / Fare Discrepancy'),
  missingItem('Missing / Incomplete Shipment'),
  unreachableRecipient('Recipient Unreachable (Driver Failure)'),
  wrongAddress('Incorrect or Inaccessible Address'),
  packageRefused('Recipient Refused Handover'),
  other('Other Operational Incident');

  final String label;
  const DisputeCategory(this.label);

  static DisputeCategory fromString(String? value) {
    if (value == null) return DisputeCategory.other;
    final normalized = value.toLowerCase().replaceAll('_', '');
    for (final cat in DisputeCategory.values) {
      if (cat.name.toLowerCase() == normalized) {
        return cat;
      }
    }
    // Handle aliases
    if (normalized.contains('fare') || normalized.contains('payment')) {
      return DisputeCategory.fareDispute;
    }
    if (normalized.contains('late') || normalized.contains('delay')) {
      return DisputeCategory.lateDelivery;
    }
    if (normalized.contains('misconduct') || normalized.contains('behavior')) {
      return DisputeCategory.driverMisconduct;
    }
    if (normalized.contains('noshow') || normalized.contains('unreachable')) {
      return DisputeCategory.noShow;
    }
    if (normalized.contains('damage')) {
      return DisputeCategory.damagedItem;
    }
    if (normalized.contains('wrong')) {
      return DisputeCategory.wrongItem;
    }
    return DisputeCategory.other;
  }
}
