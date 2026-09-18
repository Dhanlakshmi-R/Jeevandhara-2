import 'package:flutter/material.dart';
import '../../theme/colors.dart';

/// Displays a themed bottom sheet modal (mobile-first). Returns the result.
Future<T?> showAppModal<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  bool showHandle = true,
  List<Widget>? actions,
}) {
  final c = context.colors;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final bottom = MediaQuery.of(context).viewInsets.bottom;
      return Container(
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 20 + bottom),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showHandle)
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: c.textSecondary),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                child,
                if (actions != null && actions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (final action in actions) ...[
                        Expanded(child: action),
                        if (action != actions.last) const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Centered dialog helper.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  List<Widget>? actions,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: child,
        actions: actions,
      );
    },
  );
}