import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class CustomAppBar extends AppBar {
  final Widget titleWidget;
  final List<Widget>? additionalActions;

  CustomAppBar({
    this.titleWidget = const Text(
      'Blossom',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
    this.additionalActions,
    super.key,
    super.leading,
    super.automaticallyImplyLeading,
  }) : super(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: Stack(
            children: [
              _MoveWindowArea(),
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 2,
                child: _ResizeArea(cursor: SystemMouseCursors.resizeLeft, direction: _ResizeDirection.left),
              ),
              const Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 2,
                child: _ResizeArea(cursor: SystemMouseCursors.resizeRight, direction: _ResizeDirection.right),
              ),
              const Positioned(
                left: 0,
                top: 0,
                right: 0,
                height: 2,
                child: _ResizeArea(cursor: SystemMouseCursors.resizeUp, direction: _ResizeDirection.top),
              ),
            ],
          ),
          actions: [
            if (additionalActions != null) ...additionalActions,
            if (!Platform.isMacOS) ...[
              _WindowButton(
                icon: Icons.remove,
                onPressed: () => windowManager.minimize(),
                tooltip: 'Minimize',
              ),
              _WindowButton(
                icon: Icons.crop_square_outlined,
                onPressed: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
                tooltip: 'Maximize',
              ),
              _WindowButton(
                icon: Icons.close,
                onPressed: () => windowManager.close(),
                tooltip: 'Close',
                isClose: true,
              ),
              const SizedBox(width: 2),
            ],
          ],
          title: titleWidget,
          toolbarHeight: 38,
          elevation: 0,
          shadowColor: Colors.transparent,
        );
}

enum _ResizeDirection {
  left,
  right,
  top,
  topLeft,
  topRight,
}

class _ResizeArea extends StatelessWidget {
  final MouseCursor cursor;
  final _ResizeDirection direction;

  const _ResizeArea({
    required this.cursor,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (details) {
          if (!Platform.isMacOS) {
            switch (direction) {
              case _ResizeDirection.left:
                windowManager.startResizing(ResizeEdge.left);
                break;
              case _ResizeDirection.right:
                windowManager.startResizing(ResizeEdge.right);
                break;
              case _ResizeDirection.top:
                windowManager.startResizing(ResizeEdge.top);
                break;
              case _ResizeDirection.topLeft:
                windowManager.startResizing(ResizeEdge.topLeft);
                break;
              case _ResizeDirection.topRight:
                windowManager.startResizing(ResizeEdge.topRight);
                break;
            }
          }
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.isClose = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 38,
      child: IconButton(
        icon: Icon(icon, size: 16),
        onPressed: onPressed,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(),
          hoverColor: isClose ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        ),
      ),
    );
  }
}

class _MoveWindowArea extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        if (!Platform.isMacOS) {
          windowManager.startDragging();
        }
      },
      onDoubleTap: () async {
        if (!Platform.isMacOS) {
          if (await windowManager.isMaximized()) {
            windowManager.unmaximize();
          } else {
            windowManager.maximize();
          }
        }
      },
      child: const SizedBox.expand(),
    );
  }
}
