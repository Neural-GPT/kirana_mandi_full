/// App-wide constants. Centralised so screens never hardcode
/// role strings, shop-status strings, etc.
class AppConstants {
  AppConstants._();

  static const String appName = 'Kirana Mandi';

  // --- Company / contact info (shown in Settings > Contact Us) ---
  static const String companyName = 'Innovaneers Technologies';
  static const String companyPhone = '+91 9654226678';

  // --- User roles ---
  static const String roleCustomer = 'customer';
  static const String roleShopkeeper = 'shopkeeper';
  static const String roleAdmin = 'admin';
  static const String roleSuperAdmin = 'super_admin';

  static bool isAdminRole(String role) =>
      role == roleAdmin || role == roleSuperAdmin;

  // --- Shop approval status ---
  static const String shopStatusPending = 'pending';
  static const String shopStatusApproved = 'approved';
  static const String shopStatusRejected = 'rejected';

  // --- Category types (shared categories table) ---
  static const String categoryTypeShop = 'shop';
  static const String categoryTypeProduct = 'product';

  // --- Dev-only OTP ---
  // Used by DevAuthRepository so the flow can be tested without an SMS
  // gateway configured. TextbeeAuthRepository (see auth_repository.dart)
  // generates and sends a real one-time code via textbee.dev instead.
  // Whether real SMS is used at all is now driven by EnvConfig
  // (lib/core/constants/env_config.dart) -- see main.dart.
  static const String devOtpCode = '1234';

  static const Duration otpValidity = Duration(minutes: 5);

  // --- Order status (customer places an order -> shopkeeper actions it) ---
  static const String orderStatusPlaced = 'placed';
  static const String orderStatusAccepted = 'accepted';
  static const String orderStatusRejected = 'rejected';
  static const String orderStatusPreparing = 'preparing';
  static const String orderStatusOutForDelivery = 'out_for_delivery';
  static const String orderStatusDelivered = 'delivered';
  static const String orderStatusCancelled = 'cancelled';

  static const List<String> activeOrderStatuses = [
    orderStatusPlaced,
    orderStatusAccepted,
    orderStatusPreparing,
    orderStatusOutForDelivery,
  ];

  static String orderStatusLabel(String status) {
    switch (status) {
      case orderStatusPlaced:
        return 'Order Placed';
      case orderStatusAccepted:
        return 'Accepted by Shop';
      case orderStatusRejected:
        return 'Rejected';
      case orderStatusPreparing:
        return 'Preparing';
      case orderStatusOutForDelivery:
        return 'Out for Delivery';
      case orderStatusDelivered:
        return 'Delivered';
      case orderStatusCancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }
}

