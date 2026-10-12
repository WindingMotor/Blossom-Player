import 'package:flutter/material.dart';

/// Shared entrance treatment for Blossom's primary pages.
class BlossomPageEntrance extends StatefulWidget {
  final Widget child;

  const BlossomPageEntrance({super.key, required this.child});

  @override
  State<BlossomPageEntrance> createState() => _BlossomPageEntranceState();
}

class _BlossomPageEntranceState extends State<BlossomPageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  )..forward();

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeIn,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
