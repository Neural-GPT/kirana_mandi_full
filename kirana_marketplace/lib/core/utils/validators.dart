class Validators {
  Validators._();

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final digits = value.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return 'Enter a valid 10-digit phone number';
    }
    return null;
  }

  static String? required(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? price(String? value) {
    if (value == null || value.trim().isEmpty) return 'Price is required';
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed < 0) return 'Enter a valid price';
    return null;
  }

  static String? nonNegativeNumber(String? value, {String label = 'Value'}) {
    if (value == null || value.trim().isEmpty) return null; // optional field
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed < 0) return 'Enter a valid $label';
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.trim().length != 4) return 'Enter the 4-digit OTP';
    return null;
  }
}
