/// Centralized Asset Paths for e-Hailer
///
/// Organized by feature modules with universal shortcuts via [AppAssets].
library;

/// Assets for Authentication and Profiles
abstract class AuthAssets {
  static const String appLogo = 'assets/images/app_logo.png';
  static const String avatarPlaceholder = 'assets/images/avatar_placeholder.png';
  static const String authBackground = 'assets/images/auth_bg.png';
}

/// Assets for Deliveries, Consignments, and Vehicles
abstract class DeliveryAssets {
  // Vehicle Category Representations
  static const String vehicleMotorcycle = 'assets/images/vehicle_motorcycle.png';
  static const String vehicleSedan = 'assets/images/vehicle_sedan.png';
  static const String vehicleVan = 'assets/images/vehicle_van.png';
  static const String vehicleTruck = 'assets/images/vehicle_truck.png';

  // Consignment & Logistics Graphics
  static const String packageBox = 'assets/images/package_box.png';
  static const String waybillStamp = 'assets/images/waybill_stamp.png';
  static const String deliverySuccess = 'assets/images/delivery_success.png';
  static const String emptyOrders = 'assets/images/empty_orders.png';
}

/// Assets for OpenStreetMap Visual Overlays & Markers
abstract class MapAssets {
  static const String pinPickup = 'assets/icons/pin_pickup.svg';
  static const String pinDropoff = 'assets/icons/pin_dropoff.svg';
  static const String driverMarker = 'assets/icons/driver_marker.png';
  static const String liveLocationGps = 'assets/icons/live_location.svg';
}

/// Universal Asset Registry
abstract class AppAssets {
  // Brand & Identity
  static const String appLogo = AuthAssets.appLogo;
  static const String avatarPlaceholder = AuthAssets.avatarPlaceholder;

  // Vehicles
  static const String vehicleMotorcycle = DeliveryAssets.vehicleMotorcycle;
  static const String vehicleSedan = DeliveryAssets.vehicleSedan;
  static const String vehicleVan = DeliveryAssets.vehicleVan;
  static const String vehicleTruck = DeliveryAssets.vehicleTruck;

  // Delivery & States
  static const String packageBox = DeliveryAssets.packageBox;
  static const String waybillStamp = DeliveryAssets.waybillStamp;
  static const String deliverySuccess = DeliveryAssets.deliverySuccess;
  static const String emptyOrders = DeliveryAssets.emptyOrders;

  // Map & Geo Markers
  static const String pinPickup = MapAssets.pinPickup;
  static const String pinDropoff = MapAssets.pinDropoff;
  static const String driverMarker = MapAssets.driverMarker;
  static const String liveLocationGps = MapAssets.liveLocationGps;
}
