import 'package:flutter/material.dart';

/// Opens a Blossom-styled modal sheet with one consistent route animation.
///
/// Sheet widgets own their visual surface; this helper owns route behavior so
/// callers do not repeatedly configure animation, safe areas, and transparency.
Future<T?> showBlossomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool enableDrag = true,
  bool isDismissible = true,
  Color backgroundColor = Colors.transparent,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (context) => RepaintBoundary(child: builder(context)),
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    enableDrag: enableDrag,
    isDismissible: isDismissible,
    backgroundColor: backgroundColor,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 260),
      reverseDuration: Duration(milliseconds: 200),
    ),
  );
}
