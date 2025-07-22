import 'dart:ui';

import 'package:blossom/sheets/lyrics_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';

class PlayingSongsSheet extends StatefulWidget {
  const PlayingSongsSheet({Key? key}) : super(key: key);

  @override
  _PlayingSongsSheetState createState() => _PlayingSongsSheetState();
}

class _PlayingSongsSheetState extends State<PlayingSongsSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late ScrollController _scrollController;
  bool _showScrollToTop = false;
  bool _isReorderMode = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200), // Reduced animation time
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _scrollController = ScrollController();
    
    _scrollController.addListener(() {
      if (mounted) {
        final showScrollToTop = _scrollController.offset > 200;
        if (_showScrollToTop != showScrollToTop) {
          setState(() {
            _showScrollToTop = showScrollToTop;
          });
        }
      }
    });
    
    _controller.forward();
    
    // Auto-scroll to currently playing song after animation completes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 50), () { // Reduced delay
          if (mounted) {
            _scrollToCurrentSong();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentSong() {
    final player = Provider.of<NPlayer>(context, listen: false);
    final currentSong = player.getCurrentSong();
    if (currentSong != null && _scrollController.hasClients) {
      final currentIndex = player.playingSongs.indexWhere((song) => song.path == currentSong.path);
      if (currentIndex != -1) {
        // Calculate position with better precision for compact tiles
        const double itemHeight = 64.0; // Reduced height for compact tiles
        const double headerHeight = 160.0; // Reduced header height
        final double viewportHeight = MediaQuery.of(context).size.height * 0.8;
        
        // Position the current song in the upper third of the viewport
        final double targetOffset = (currentIndex * itemHeight) - (viewportHeight * 0.25);
        final double maxScrollExtent = _scrollController.position.maxScrollExtent;
        
        final double scrollPosition = targetOffset.clamp(0.0, maxScrollExtent);
        
        _scrollController.animateTo(
          scrollPosition,
          duration: const Duration(milliseconds: 600), // Reduced duration
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, _) {
        final currentSong = player.getCurrentSong();
        if (currentSong == null) {
          return _buildEmptyState(context);
        }

        final totalDuration = player.playingSongs.fold<Duration>(
          Duration.zero,
          (total, song) => total + Duration(milliseconds: song.duration),
        );

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, (1 - _animation.value) * 50), // Reduced translation
              child: Opacity(
                opacity: _animation.value,
                child: child,
              ),
            );
          },
          child: Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor, // Simplified background
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2), // Reduced shadow
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildDragHandle(),
                    _buildCompactHeader(context, player, currentSong),
                    _buildCompactStats(context, player, totalDuration),
                    _buildControls(context, player),
                    const SizedBox(height: 4),
                    Expanded(
                      child: _buildSongsList(context, player),
                    ),
                  ],
                ),
                if (_showScrollToTop)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton.small(
                      onPressed: _scrollToTop,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.keyboard_arrow_up_rounded),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDragHandle(),
          const SizedBox(height: 40),
          Icon(
            Icons.queue_music_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No songs in queue',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start playing music to see your queue',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }

  Widget _buildCompactHeader(BuildContext context, NPlayer player, Music currentSong) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), // Reduced padding
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8), // Smaller radius
            child: Container(
              width: 48, // Smaller size
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                  ],
                ),
              ),
              child: currentSong.picture != null
                  ? Image.memory(currentSong.picture!, fit: BoxFit.cover)
                  : Icon(Icons.album_rounded, size: 24, color: Colors.grey[400]), // Smaller icon
            ),
          ),
          const SizedBox(width: 12), // Reduced spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Playing Queue',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith( // Smaller title
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${currentSong.title} • ${currentSong.artist}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith( // Smaller subtitle
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStats(BuildContext context, NPlayer player, Duration totalDuration) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), // Reduced padding
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.5), // More subtle background
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Reduced padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCompactStatItem(
                context, 
                Icons.queue_music_rounded, 
                player.playingSongs.length.toString(), 
                'Songs'
              ),
              _buildCompactStatItem(
                context, 
                Icons.album_rounded, 
                player.playingSongs.map((s) => s.album).toSet().length.toString(), 
                'Albums'
              ),
              _buildCompactStatItem(
                context, 
                Icons.access_time_rounded, 
                _formatDuration(totalDuration), 
                'Total'
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStatItem(BuildContext context, IconData icon, String value, String label) {
    return Row( // Changed to Row layout for more compact display
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16, // Smaller icon
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith( // Smaller text
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, NPlayer player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), // Reduced padding
      child: Row(
        children: [
          Expanded(
            child: _buildControlButton(
              context,
              icon: Icons.shuffle_rounded,
              label: 'Shuffle',
              onPressed: () {
                HapticFeedback.lightImpact();
                player.shuffle();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Queue shuffled'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6), // Reduced spacing
          Expanded(
            child: _buildControlButton(
              context,
              icon: Icons.my_location_rounded,
              label: 'Current',
              onPressed: () {
                HapticFeedback.lightImpact();
                _scrollToCurrentSong();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildControlButton(
              context,
              icon: Icons.lyrics_rounded,
              label: 'Lyrics',
              onPressed: () {
                final currentSong = player.getCurrentSong();
                if (currentSong != null) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => LyricsSheet(
                      artist: currentSong.artist,
                      title: currentSong.title,
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildControlButton(
              context,
              icon: _isReorderMode ? Icons.check_rounded : Icons.reorder_rounded,
              label: _isReorderMode ? 'Done' : 'Reorder',
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isReorderMode = !_isReorderMode;
                });
              },
              isActive: _isReorderMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Material(
      color: isActive 
          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
          : Theme.of(context).colorScheme.surface.withOpacity(0.5),
      borderRadius: BorderRadius.circular(8), // Smaller radius
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), // Reduced padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18, // Smaller icon
                color: isActive 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: 2), // Reduced spacing
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isActive 
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[600],
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 11, // Smaller font
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongsList(BuildContext context, NPlayer player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: OrientationBuilder(
        builder: (context, orientation) {
          if (_isReorderMode) {
            return ReorderableListView.builder(
              scrollController: _scrollController,
              itemCount: player.playingSongs.length,
              onReorder: (oldIndex, newIndex) {
                HapticFeedback.mediumImpact();
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                
                // Create new list with reordered songs
                final List<Music> reorderedSongs = List.from(player.playingSongs);
                final Music item = reorderedSongs.removeAt(oldIndex);
                reorderedSongs.insert(newIndex, item);
                
                // Update the player's queue
                player.reorderPlayingSongs(reorderedSongs);
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 6.0, // Reduced elevation
                      child: Transform.scale(
                        scale: 1.01, // Reduced scale
                        child: child,
                      ),
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final song = player.playingSongs[index];
                final isCurrentSong = player.getCurrentSong()?.path == song.path;
                
                return Container(
                  key: ValueKey(song.path),
                  margin: const EdgeInsets.only(bottom: 4), // Reduced margin
                  child: _buildCompactSongTile(context, song, index, isCurrentSong, player, true),
                );
              },
            );
          } else {
            // Optimized ListView with addAutomaticKeepAlives: false for better performance
            return ListView.builder(
              controller: _scrollController,
              itemCount: player.playingSongs.length,
              padding: const EdgeInsets.only(bottom: 16),
              addAutomaticKeepAlives: false, // Performance optimization
              addRepaintBoundaries: false, // Performance optimization
              itemBuilder: (context, index) {
                final song = player.playingSongs[index];
                final isCurrentSong = player.getCurrentSong()?.path == song.path;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 4), // Reduced margin
                  child: _buildCompactSongTile(context, song, index, isCurrentSong, player, false),
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildCompactSongTile(
    BuildContext context, 
    Music song, 
    int index, 
    bool isCurrentSong, 
    NPlayer player,
    bool isReorderMode
  ) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 56, // Fixed compact height
        decoration: BoxDecoration(
          color: isCurrentSong 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8), // Smaller radius
          border: isCurrentSong 
              ? Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3))
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            HapticFeedback.selectionClick();
            player.playSpecificSong(song);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Reduced padding
            child: Row(
              children: [
                if (isReorderMode)
                  Icon(
                    Icons.drag_handle_rounded,
                    color: Colors.grey[400],
                    size: 18,
                  )
                else
                  SizedBox(
                    width: 20, // Compact number width
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isCurrentSong 
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[500],
                        fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11, // Smaller font
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6), // Smaller radius
                  child: SizedBox(
                    width: 40, // Smaller image
                    height: 40,
                    child: song.picture != null
                        ? Image.memory(song.picture!, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.music_note_rounded, color: Colors.grey[400], size: 20),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isCurrentSong ? FontWeight.w600 : FontWeight.normal,
                          color: isCurrentSong 
                              ? Theme.of(context).colorScheme.primary 
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${song.artist} • ${_formatDuration(Duration(milliseconds: song.duration))}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                          fontSize: 11, // Smaller font
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isCurrentSong)
                  Icon(
                    Icons.play_arrow_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20, // Smaller icon
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else {
      return "${minutes}:${seconds.toString().padLeft(2, '0')}";
    }
  }
}