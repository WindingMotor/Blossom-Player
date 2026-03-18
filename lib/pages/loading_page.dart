import 'package:blossom/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../audio/nplayer.dart';

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
  
  String _loadingStatus = 'Starting up...';
  String _detailStatus = '';
  int _songsLoaded = 0;
  bool _isInitialized = false;
  int _loadRate = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _monitorLoadingProgress();
    });
  }

  void _monitorLoadingProgress() async {
    final nPlayer = Provider.of<NPlayer>(context, listen: false);
    
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    
    int lastSongCount = -1;
    int stableCount = 0;
    int lastUpdateCount = 0;
    final loadStartTime = DateTime.now();
    
    while (mounted && !_isInitialized) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) break;
      
      final currentSongCount = nPlayer.allSongs.length;
      final elapsed = DateTime.now().difference(loadStartTime).inSeconds;
      
      // Calculate load rate
      final newSongs = currentSongCount - lastUpdateCount;
      if (newSongs > 0) {
        _loadRate = (newSongs / 0.2).round();
        lastUpdateCount = currentSongCount;
      }
      
      setState(() {
        _songsLoaded = currentSongCount;
        
        // More descriptive status messages
        if (currentSongCount == 0) {
          if (elapsed < 3) {
            _loadingStatus = 'Initializing audio engine...';
            _detailStatus = elapsed < 2 
                ? 'Connecting to media scanner'
                : 'Scanning music directories';
          } else {
             _loadingStatus = 'Finalizing...';
             _detailStatus = 'Checking storage';
          }
        } else if (currentSongCount < 10) {
          _loadingStatus = 'Discovering music files...';
          _detailStatus = 'Reading file metadata and album art';
        } else if (currentSongCount < 50) {
          _loadingStatus = 'Building your library...';
          _detailStatus = '$currentSongCount tracks found • Indexing metadata';
        } else if (currentSongCount < 100) {
          _loadingStatus = 'Populating library cache...';
          _detailStatus = '$currentSongCount tracks • Parsing audio tags';
        } else if (currentSongCount < 500) {
          _loadingStatus = 'Creating library index...';
          final rate = _loadRate > 0 ? ' • ${_loadRate}/sec' : '';
          _detailStatus = '$currentSongCount tracks loaded$rate';
        } else if (currentSongCount < 1000) {
          _loadingStatus = 'Processing large library...';
          final rate = _loadRate > 0 ? ' • ${_loadRate}/sec' : '';
          _detailStatus = '$currentSongCount tracks • Building cache$rate';
        } else {
          _loadingStatus = 'Loading collection...';
          final rate = _loadRate > 0 ? ' (${_loadRate}/sec)' : '';
          final mins = (elapsed / 60).floor();
          final secs = elapsed % 60;
          final time = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
          _detailStatus = '$currentSongCount tracks • Elapsed: $time$rate';
        }
      });
      
      // --- FIXED STABILITY LOGIC ---
      
      // Case 1: Empty Library (0 songs)
      // If 0 songs found after 3 seconds, we assume the device is empty and proceed.
      if (currentSongCount == 0 && elapsed >= 3) {
        _log("Empty library detected (3s elapsed) - proceeding");
        _isInitialized = true;
        break;
      }

      // Case 2: Normal Loading Stability Check
      // If count hasn't changed since last check...
      if (currentSongCount > 0 && currentSongCount == lastSongCount) {
        stableCount++;
        // Wait for 3 stable checks (approx 600ms) before finishing
        final requiredStable = currentSongCount > 1000 ? 5 : 3;
        
        if (stableCount >= requiredStable) {
           _log("Library stable at $currentSongCount songs - proceeding");
          _isInitialized = true;
          break;
        }
      } else {
        // Count changed, reset stability counter
        if (currentSongCount != lastSongCount) {
            stableCount = 0;
        }
      }
      
      lastSongCount = currentSongCount;
      
      // Safety Timeout: 10 seconds (down from 15 mins)
      if (elapsed > 10) {
        _log("Safety timeout reached (10s) - forcing entry");
        _isInitialized = true;
        break;
      }
    }
    
    // Complete and Transition
    if (mounted) {
      setState(() {
        _loadingStatus = 'Library ready!';
        _detailStatus = _songsLoaded > 0 
            ? '$_songsLoaded songs indexed' 
            : 'No music found';
      });
      
      await Future.delayed(const Duration(milliseconds: 600));
      
    if (mounted) {
      _fadeController.forward().then((_) {
        if (mounted) {
          setState(() {
            _isLoading = false; // Simply remove the overlay
          });
        }
      });
    }

    }
  }

  void _log(String message) {
    debugPrint("[LoadingPage] $message");
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
        startY: -50 - random.nextDouble() * size.height,
        size: 20 + random.nextDouble() * 30,
        delay: random.nextDouble() * 3,
        colorFilter: ColorFilter.mode(
          widget.theme.colorScheme.secondary.withOpacity(0.4 + random.nextDouble() * 0.3),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo
                              SvgPicture.asset(
                                'assets/BlossomLogo.svg',
                                width: 150,
                                height: 150,
                                colorFilter: ColorFilter.mode(
                                  widget.theme.colorScheme.secondary,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // App Name
                              Text(
                                'Blossom',
                                style: TextStyle(
                                  fontFamily: 'Magic Retro',
                                  fontSize: 38,
                                  color: widget.theme.colorScheme.secondary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              
                              const SizedBox(height: 48),
                              
                              // Loading Status
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.1),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Column(
                                  key: ValueKey(_loadingStatus),
                                  children: [
                                    Text(
                                      _loadingStatus,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: widget.theme.colorScheme.onSurface,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    if (_detailStatus.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        _detailStatus,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: widget.theme.colorScheme.onSurface
                                              .withOpacity(0.65),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 32),
                              
                              // Loading Indicator
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: !_isInitialized
                                    ? SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            widget.theme.colorScheme.secondary,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.check_circle_rounded,
                                        size: 40,
                                        color: widget.theme.colorScheme.secondary,
                                      ),
                              ),
                            ],
                          ),
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
  final double delay;
  final ColorFilter colorFilter;

  const FallingBlossom({
    Key? key,
    required this.startX,
    required this.startY,
    required this.size,
    required this.colorFilter,
    this.delay = 0,
  }) : super(key: key);

  @override
  _FallingBlossomState createState() => _FallingBlossomState();
}

class _FallingBlossomState extends State<FallingBlossom>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animationY;
  late double _horizontalAmplitude;
  late double _horizontalFrequency;
  late double _rotationSpeed;
  late double _phase;
  final random = Random();

  @override
  void initState() {
    super.initState();
    
    // Random wind characteristics for each blossom
    _horizontalAmplitude = 30 + random.nextDouble() * 50; // Wind drift amount
    _horizontalFrequency = 0.8 + random.nextDouble() * 0.6; // Wind wave frequency
    _rotationSpeed = 2 + random.nextDouble() * 4; // Rotation speed
    _phase = random.nextDouble() * 2 * pi; // Random starting phase
    
    _controller = AnimationController(
      duration: Duration(seconds: 6 + random.nextInt(6)),
      vsync: this,
    );
    
    // Start animation immediately
    _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    
    _animationY = Tween<double>(
      begin: widget.startY,
      end: size.height + 50,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Sinusoidal horizontal movement for wind effect
        final windOffset = _horizontalAmplitude * 
            sin(_horizontalFrequency * _controller.value * 2 * pi + _phase);
        
        // Smooth rotation with some randomness
        final rotation = _rotationSpeed * _controller.value * 2 * pi;
        
        // Add subtle scale variation to simulate depth
        final scale = 0.9 + 0.1 * sin(_controller.value * 2 * pi);
        
        return Positioned(
          left: widget.startX + windOffset,
          top: _animationY.value,
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotation,
              child: SvgPicture.asset(
                'assets/BlossomLogo.svg',
                width: widget.size,
                height: widget.size,
                colorFilter: widget.colorFilter,
              ),
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
