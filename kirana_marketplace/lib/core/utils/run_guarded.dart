import 'package:flutter/material.dart';
import '../errors/exceptions.dart';

/// Runs [action], and on any thrown error shows a friendly SnackBar via
/// [friendlyErrorMessage] instead of letting the exception surface as a
/// red error screen or a silent failure. Returns the action's result, or
/// null if it threw.
///
/// Used for the mutating operations users click a button to trigger
/// (save shop, add product, log a sale, add an admin, etc.) so every one
/// of them gets the same "something went wrong" safety net.
Future<T?> runGuarded<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? successMessage,
}) async {
  try {
    final result = await action();
    if (successMessage != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    }
    return result;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage(error)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
    return null;
  }
}
