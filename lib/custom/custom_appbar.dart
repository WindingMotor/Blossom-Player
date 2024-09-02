import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class CustomAppBar extends AppBar {
  final Widget titleWidget;

  CustomAppBar({
    this.titleWidget = const Text('Blossom'),
    super.key,
    super.leading,
    super.automaticallyImplyLeading,
  }) : super(
          actions: [
            if (!Platform.isMacOS)
              IconButton(
                icon: Icon(Icons.minimize, color: Colors.pink.shade300),
                onPressed: () => windowManager.minimize(),
              ),
            if (!Platform.isMacOS)
              IconButton(
                icon: Icon(Icons.crop_square, color: Colors.pink.shade300),
                onPressed: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
              ),
            if (!Platform.isMacOS)
              IconButton(
                icon: Icon(Icons.close, color: Colors.pink.shade300),
                onPressed: () => windowManager.close(),
              ),
          ],
          title: SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: _MoveWindowArea(
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child: titleWidget,
                    ),
                  ),
                ),
              ],
            ),
          ),
          elevation: 1,
        );
}

class _MoveWindowArea extends StatelessWidget {
  final Widget? child;

  const _MoveWindowArea({this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        windowManager.startDragging();
      },
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: child ?? Container(),
    );
  }
}
