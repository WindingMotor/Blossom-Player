import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_svg/svg.dart';
import 'dart:math';

class LoadingPage extends StatefulWidget {
  final Widget child;
  final ThemeData theme;

  const LoadingPage({Key? key, required this.child, required this.theme})
      : super(key: key);

  @override
  _LoadingPageState createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  final List<FallingBlossom> _blossoms = [];
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);

    Timer(const Duration(seconds: 5), () {
      _fadeController.forward().then((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_blossoms.isEmpty) {
      _generateBlossoms();
    }
  }

  void _generateBlossoms() {
    final random = Random();
    final size = MediaQuery.of(context).size;
    for (int i = 0; i < 20; i++) {
      _blossoms.add(FallingBlossom(
        startX: random.nextDouble() * size.width,
        startY: random.nextDouble() * size.height * -1,
        size: 20 + random.nextDouble() * 30,
        colorFilter: ColorFilter.mode(
          widget.theme.colorScheme.secondary.withOpacity(0.5),
          BlendMode.srcIn,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isLoading)
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Scaffold(
                  backgroundColor: widget.theme.scaffoldBackgroundColor,
                  body: Stack(
                    children: [
                      ..._blossoms,
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              'assets/BlossomLogo.svg',
                              width: 150,
                              height: 150,
                              colorFilter: ColorFilter.mode(
                                widget.theme.colorScheme.secondary,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Blossom',
                              style: TextStyle(
                                fontSize: 38,
                                color: widget.theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class FallingBlossom extends StatefulWidget {
  final double startX;
  final double startY;
  final double size;
  final ColorFilter colorFilter;

  const FallingBlossom({
    Key? key,
    required this.startX,
    required this.startY,
    required this.size,
    required this.colorFilter,
  }) : super(key: key);

  @override
  _FallingBlossomState createState() => _FallingBlossomState();
}

class _FallingBlossomState extends State<FallingBlossom>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animationY;
  late Animation<double> _animationX;
  late Animation<double> _animationRotation;
  final random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 5 + random.nextInt(5)),
      vsync: this,
    );
    _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;

    _animationY = Tween<double>(begin: widget.startY, end: size.height)
        .animate(_controller);

    // Random horizontal movement
    final endX = widget.startX +
        (random.nextDouble() - 0.5) * 100; // Move up to 50 pixels left or right
    _animationX =
        Tween<double>(begin: widget.startX, end: endX).animate(_controller);

    // Random rotation
    _animationRotation =
        Tween<double>(begin: 0, end: random.nextDouble() * 4 * pi)
            .animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _animationX.value,
          top: _animationY.value,
          child: Transform.rotate(
            angle: _animationRotation.value,
            child: SvgPicture.asset(
              'assets/BlossomLogo.svg',
              width: widget.size,
              height: widget.size,
              colorFilter: widget.colorFilter,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
