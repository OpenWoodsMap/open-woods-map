import 'package:flutter/material.dart';

/// Shows [message] at the bottom of the screen as the only message there.
///
/// Two things this fixes about calling `showSnackBar` directly.
///
/// Messages used to queue. A few actions in a row left a pile to be dismissed
/// one at a time, and the older ones were still offering to undo work that had
/// since been undone, built on, or deleted. Only the newest message can still be
/// true about what just happened, so a new one replaces the one on screen.
///
/// And they had no visible way out. Swiping down worked but nothing said so, so
/// they read as stuck. [SnackBar.showCloseIcon] is Material's own answer and
/// sits alongside an action rather than replacing it.
///
/// Uses `maybeOf` so a host without a [ScaffoldMessenger] gets silence rather
/// than an exception. It does still need a [Scaffold] somewhere in the tree, as
/// `showSnackBar` itself does; every caller here is on or above one.
void showMessage(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
  SnackBarBehavior? behavior,
}) {
  assert(
    (actionLabel == null) == (onAction == null),
    'An action needs both a label and something to do.',
  );
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        showCloseIcon: true,
        behavior: behavior,
        duration: duration ?? const Duration(seconds: 4),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction!),
      ),
    );
}
