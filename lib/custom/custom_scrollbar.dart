import 'dart:math';
import 'package:flutter/material.dart';

class CustomScrollbarPainter extends CustomPainter {
  final ScrollMetrics metrics;
  final Color thumbColor;
  final double thumbWidth;
  final bool isThumbPressed;
  final String currentPosition;

  CustomScrollbarPainter({
    required this.metrics,
    required this.thumbColor,
    this.thumbWidth = 8.0,
    this.isThumbPressed = false,
    this.currentPosition = '',
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scrollbarSize = max(size.width, thumbWidth);
    final thumbExtent = scrollbarSize / metrics.viewportDimension * metrics.viewportDimension;
    final thumbOffset = scrollbarSize / metrics.viewportDimension * metrics.pixels;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width - scrollbarSize,
          thumbOffset,
          scrollbarSize,
          thumbExtent,
        ),
        Radius.circular(scrollbarSize / 2),
      ),
      Paint()..color = thumbColor,
    );

    if (isThumbPressed) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: currentPosition,
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - scrollbarSize - textPainter.width - 8, thumbOffset - 20));
    }
  }

  @override
  bool shouldRepaint(CustomScrollbarPainter oldDelegate) {
    return metrics != oldDelegate.metrics ||
           thumbColor != oldDelegate.thumbColor ||
           thumbWidth != oldDelegate.thumbWidth ||
           isThumbPressed != oldDelegate.isThumbPressed ||
           currentPosition != oldDelegate.currentPosition;
  }
}

class CustomScrollbar extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;

  const CustomScrollbar({
    Key? key,
    required this.child,
    required this.scrollController,
  }) : super(key: key);

  @override
  _CustomScrollbarState createState() => _CustomScrollbarState();
}

class _CustomScrollbarState extends State<CustomScrollbar> {
  bool _isThumbPressed = false;
  String _currentPosition = '';

  void _updatePosition() {
    final itemCount = widget.scrollController.position.maxScrollExtent ~/ 50; // Assuming each item is 50 pixels high
    final currentItem = (widget.scrollController.offset / 50).round() + 1;
    setState(() {
      _currentPosition = '$currentItem / $itemCount';
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _updatePosition();
        }
        return false;
      },
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onVerticalDragStart: (_) => setState(() => _isThumbPressed = true),
                  onVerticalDragEnd: (_) => setState(() => _isThumbPressed = false),
                  onVerticalDragUpdate: (details) {
                    final scrollableSize = widget.scrollController.position.maxScrollExtent;
                    final thumbMoveDistance = details.delta.dy / constraints.maxHeight * scrollableSize;
                    widget.scrollController.jumpTo(widget.scrollController.offset + thumbMoveDistance);
                  },
                  child: CustomPaint(
                    painter: CustomScrollbarPainter(
                      metrics: widget.scrollController.position,
                      thumbColor: Colors.grey.withOpacity(0.8),
                      thumbWidth: 12.0,
                      isThumbPressed: _isThumbPressed,
                      currentPosition: _currentPosition,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}