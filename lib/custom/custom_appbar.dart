import 'dart:io';
import 'package:flutter/foundation.dart';
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
          toolbarHeight: kIsWeb || Platform.isAndroid || Platform.isIOS ? 56.0 : 48.0,
          flexibleSpace: Stack(
            children: [
              if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) ...[
                _MoveWindowArea(),
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 8,
                  child: _ResizeArea(cursor: SystemMouseCursors.resizeLeft, direction: _ResizeDirection.left),
                ),
                const Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 8,
                  child: _ResizeArea(cursor: SystemMouseCursors.resizeRight, direction: _ResizeDirection.right),
                ),
                const Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  height: 8,
                  child: _ResizeArea(cursor: SystemMouseCursors.resizeUp, direction: _ResizeDirection.top),
                ),
                // Corner resize areas
                const Positioned(
                  left: 0,
                  top: 0,
                  width: 12,
                  height: 12,
                  child: _ResizeArea(cursor: SystemMouseCursors.resizeUpLeft, direction: _ResizeDirection.topLeft),
                ),
                const Positioned(
                  right: 0,
                  top: 0,
                  width: 12,
                  height: 12,
                  child: _ResizeArea(cursor: SystemMouseCursors.resizeUpRight, direction: _ResizeDirection.topRight),
                ),
              ],
              if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) ...[
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 8,
                  child: _ResizeArea(cursor: SystemMouseCursors.resizeLeft, direction: _ResizeDirection.left),
                ),
                const Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 8,
                  child: _ResizeArea(cursor: SystemMouseCursors.resizeRight, direction: _ResizeDirection.right),
                ),
                const Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  height: 8,
                  child: _ResizeArea(cursor: SystemMouseCursors.resizeUp, direction: _ResizeDirection.top),
                ),
              ],
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

class _ResizeArea extends StatefulWidget {
  final MouseCursor cursor;
  final _ResizeDirection direction;

  const _ResizeArea({
    required this.cursor,
    required this.direction,
  });

  @override
  State<_ResizeArea> createState() => _ResizeAreaState();
}

class _ResizeAreaState extends State<_ResizeArea> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => isHovering = true),
      onExit: (_) => setState(() => isHovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (details) {
          switch (widget.direction) {
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
        },
        child: Container(
          color: isHovering ? Theme.of(context).colorScheme.secondary.withOpacity(0.2) : Colors.transparent,
        ),
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

class CustomSearchBar extends StatelessWidget implements PreferredSizeWidget {
  final String hintText;
  final Function(String)? onChanged;
  final List<Widget>? actions;
  final FocusNode? focusNode;

  const CustomSearchBar({
    Key? key,
    required this.hintText,
    this.onChanged,
    this.actions,
    this.focusNode,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final screenWidth = MediaQuery.of(context).size.width;
    
    return AppBar(
      title: Container(
        width: isDesktop ? screenWidth * 0.3 : null,
        constraints: BoxConstraints(
          maxWidth: 500,
          minWidth: isDesktop ? 300 : 200,
        ),
        child: TextField(
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
            suffixIcon: IconButton(
              icon: Icon(Icons.clear, size: 20),
              onPressed: () {
                if (onChanged != null) onChanged!('');
              },
              tooltip: isDesktop ? 'Clear (Esc)' : 'Clear',
            ),
            prefixIcon: Icon(Icons.search, color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
        ),
      ),
      actions: actions,
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }
}
