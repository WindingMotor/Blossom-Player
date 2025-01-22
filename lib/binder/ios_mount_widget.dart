// ios_mount_widget.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'ios_binder.dart';

class iOSMountWidget extends StatefulWidget {
  const iOSMountWidget({super.key});

  @override
  State<iOSMountWidget> createState() => _iOSMountWidgetState();
}

class _iOSMountWidgetState extends State<iOSMountWidget> {
  Offset position = const Offset(16, 140);
  late Timer _refreshTimer;
  int? _availableSpace;
  bool _isMounted = false;
  final iOS_Binder _binder = iOS_Binder();

  @override
  void initState() {
    super.initState();
    _startSpaceCheck();
  }

  void _startSpaceCheck() {
    _checkStatus();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;

    final isMounted = await _binder.checkMountStatus();
    if (isMounted) {
      final space = await _binder.getSpaceInfo();
      setState(() {
        _isMounted = true;
        _availableSpace = space['available'];
      });
    } else {
      setState(() {
        _isMounted = false;
        _availableSpace = null;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    if (!_isMounted) return const SizedBox.shrink();

    return Positioned(
      left: position.dx,
      top: position.dy + topPadding,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final newPosition = position + details.delta;
            position = Offset(
              newPosition.dx.clamp(0, screenSize.width - 160),
              newPosition.dy.clamp(0, screenSize.height - topPadding - 60),
            );
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surface.withOpacity(0.85),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.2),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                child:
                              Icon(
                Icons.phone_iphone,
                size: 18,
                color: colorScheme.primary,
              ),
                message: 'iOS Device Connected. Songs loaded automatically.',
              ),
              const SizedBox(width: 8),
                            IconButton(
                icon: Icon(
                  Icons.folder_open,
                  size: 18,
                  color: colorScheme.primary,
                ),

                onPressed: () {
                  Process.run('xdg-open', 
                    ['${Platform.environment['HOME']}/Music/BlossomMount']);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Open Mount Folder',
              ),
              const SizedBox(width: 8),
              Text(
                '${_availableSpace ?? 0}GB Free',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
