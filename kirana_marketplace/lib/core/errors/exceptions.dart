/// Thrown by repositories when a requested record can't be found.
class NotFoundException implements Exception {
  final String message;
  NotFoundException([this.message = 'Requested record was not found.']);
  @override
  String toString() => message;
}

/// Thrown when a caller attempts an operation they don't have the
/// role/ownership to perform. The Flutter app enforces this defensively;
/// the production API must re-enforce it server-side (never trust the client).
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'You are not allowed to do that.']);
  @override
  String toString() => message;
}

/// Thrown on invalid input that failed validation before hitting storage.
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  @override
  String toString() => message;
}

/// Thrown when OTP verification fails.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Thrown when an operation needs the network (e.g. sending a real SMS via
/// textbee.dev) and the device has no connectivity. Distinct from
/// [NetworkException] so callers can offer a more specific "you're
/// offline" message rather than a generic failure.
class OfflineException implements Exception {
  final String message;
  OfflineException([this.message = "You're offline. Please check your connection and try again."]);
  @override
  String toString() => message;
}

/// Thrown when a network call (e.g. the textbee.dev SMS API) fails for a
/// reason other than being offline -- timeout, bad response, server error.
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => message;
}

/// Maps any exception thrown by the data layer to a short, non-technical
/// message safe to show directly in a SnackBar/dialog. Centralising this
/// means every screen shows consistent, friendly copy instead of a raw
/// `Exception: ...` string leaking from SQLite, http, etc (PRD-adjacent
/// "better error handling of edge cases" requirement).
String friendlyErrorMessage(Object error) {
  if (error is OfflineException) return error.message;
  if (error is NetworkException) return error.message;
  if (error is AuthException) return error.message;
  if (error is UnauthorizedException) return error.message;
  if (error is ValidationException) return error.message;
  if (error is NotFoundException) return error.message;
  // Anything else (DatabaseException, TimeoutException, FormatException,
  // etc.) gets a safe generic message rather than surfacing raw internals.
  return 'Something went wrong. Please try again.';
}
