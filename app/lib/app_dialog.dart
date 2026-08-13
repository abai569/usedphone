import 'package:flutter/material.dart';

Future<void> showAppMessage(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.info_outline,
  Color color = Colors.orange,
  String actionLabel = '确定',
  bool squareAction = false,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: Icon(icon, color: color, size: 56),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: squareAction
              ? FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
              : null,
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}
