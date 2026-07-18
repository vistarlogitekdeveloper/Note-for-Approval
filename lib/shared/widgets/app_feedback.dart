import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';

/// One place every screen tells the user whether something worked.
///
/// Before this existed, most actions said nothing at all: a dialog closed and
/// the user was left guessing whether the save landed. Anything that mutates
/// data should end in one of these calls.
class AppFeedback {
  AppFeedback._();

  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.ok, Icons.check_circle_outline);

  /// Accepts the raw error object. [ApiException] already carries a
  /// human-readable server message via `displayMessage`; anything else is
  /// stringified, which is still better than silence.
  static void error(BuildContext context, Object error) {
    final message = error is ApiException
        ? error.displayMessage
        : error.toString().replaceFirst(RegExp(r'^Exception: '), '');
    _show(context, message, AppColors.bad, Icons.error_outline, seconds: 6);
  }

  static void info(BuildContext context, String message) =>
      _show(context, message, AppColors.info, Icons.info_outline);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon, {
    int seconds = 4,
  }) {
    // An async handler can outlive the widget that started it; showing a
    // SnackBar against a dead context throws.
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: Duration(seconds: seconds),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface2,
          elevation: 8,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.45)),
          ),
          content: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: AppColors.txt, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
