import 'package:blossom/tools/logger.dart';
import 'package:blossom/tools/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';


class LyricsSheet extends StatefulWidget {
  final String artist;
  final String title;
  final Uint8List? picture;


  const LyricsSheet({
    Key? key, 
    required this.artist, 
    required this.title,
    this.picture,
  }) : super(key: key);


  @override
  _LyricsSheetState createState() => _LyricsSheetState();
}


class _LyricsSheetState extends State<LyricsSheet> with TickerProviderStateMixin {
  String _searchQuery = '';
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<String> _lyricsNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<String> _currentApiNotifier = ValueNotifier<String>('');
  int _currentMatchIndex = 0;
  int _totalMatches = 0;
  bool _showScrollToTop = false;


  @override
  void initState() {
    super.initState();
    _fetchLyrics();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    _slideController.forward();
    _fadeController.forward();
    
    _scrollController.addListener(() {
      if (_scrollController.offset > 500 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 500 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });
  }


  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _lyricsNotifier.dispose();
    _isLoadingNotifier.dispose();
    _currentApiNotifier.dispose();
    super.dispose();
  }


  Map<String, String> _getBrowserHeaders() {
    return {
      'Accept': 'application/json',
      'Accept-Language': 'en-US,en;q=0.9',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };
  }


  Future<void> _fetchLyrics() async {
    _isLoadingNotifier.value = true;
    _lyricsNotifier.value = '';
    _currentApiNotifier.value = 'Connecting to LRCLIB...';
    
    final encodedArtist = Uri.encodeComponent(widget.artist.trim());
    final encodedTitle = Uri.encodeComponent(widget.title.trim());
    
    final String apiUrl = 'https://lrclib.net/api/get?artist_name=$encodedArtist&track_name=$encodedTitle';
    
    try {
      Log.d(LogTag.ui, 'Fetching lyrics from LRCLIB: $apiUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: _getBrowserHeaders(),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds');
        },
      );

      Log.d(LogTag.ui, 'LRCLIB response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String lyrics = data['plainLyrics'] ?? data['syncedLyrics'] ?? '';

        if (lyrics.isNotEmpty && lyrics.length >= 10) {
          _lyricsNotifier.value = lyrics.trim();
          _currentApiNotifier.value = '✓ LRCLIB';
          Log.i(LogTag.ui, 'LRCLIB: lyrics loaded (${lyrics.length} chars)');

          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              _currentApiNotifier.value = '';
            }
          });
        } else {
          _showErrorMessage('LRCLIB returned empty lyrics for this song.');
        }
      } else if (response.statusCode == 404) {
        Log.d(LogTag.ui, 'LRCLIB: 404 not found for ${widget.title}');
        _showErrorMessage('Lyrics not found in LRCLIB database.');
      } else {
        Log.w(LogTag.ui, 'LRCLIB error: ${response.statusCode}');
        _showErrorMessage('LRCLIB server error (${response.statusCode})');
      }
    } on SocketException catch (e) {
      Log.w(LogTag.ui, 'LRCLIB socket error: ${e.message}');
      _showErrorMessage('Network connection failed. Check your internet connection.');
    } on TimeoutException catch (e) {
      Log.w(LogTag.ui, 'LRCLIB timeout: ${e.message}');
      _showErrorMessage('Request timed out. Please try again.');
    } on FormatException catch (e) {
      Log.w(LogTag.ui, 'LRCLIB format error: ${e.message}');
      _showErrorMessage('Invalid response format from LRCLIB.');
    } catch (e) {
      Log.e(LogTag.ui, 'LRCLIB unexpected error: $e');
      _showErrorMessage('Unexpected error occurred: $e');
    }
    
    _isLoadingNotifier.value = false;
  }


  void _showErrorMessage(String message) {
    _currentApiNotifier.value = 'Failed';
    _lyricsNotifier.value = '''❌ Unable to fetch lyrics


$message


Song: ${widget.title}
Artist: ${widget.artist}


Common issues:
• Lyrics not available in database
• Check spelling of artist/song name
• Network connectivity problems
• Server temporarily unavailable


Try tapping the refresh button to retry''';
  }


  Future<void> _retryFetch() async {
    HapticFeedback.mediumImpact();
    await _fetchLyrics();
  }


  void _updateMatchCount() {
    if (_searchQuery.isEmpty) {
      _totalMatches = 0;
      _currentMatchIndex = 0;
      return;
    }


    final queryLower = _searchQuery.toLowerCase();
    final lyricsLower = _lyricsNotifier.value.toLowerCase();
    _totalMatches = queryLower.allMatches(lyricsLower).length;
    
    if (_totalMatches > 0 && _currentMatchIndex >= _totalMatches) {
      _currentMatchIndex = 0;
    } else if (_totalMatches == 0) {
      _currentMatchIndex = 0;
    }
  }


  void _navigateToNextMatch() {
    if (_totalMatches > 0) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentMatchIndex = (_currentMatchIndex + 1) % _totalMatches;
      });
    }
  }


  void _navigateToPreviousMatch() {
    if (_totalMatches > 0) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentMatchIndex = (_currentMatchIndex - 1 + _totalMatches) % _totalMatches;
      });
    }
  }


  void _copyLyrics() {
    Clipboard.setData(ClipboardData(text: _lyricsNotifier.value));
    HapticFeedback.mediumImpact();
  }


  void _scrollToTop() {
    HapticFeedback.lightImpact();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }


  List<TextSpan> _highlightOccurrences(String source, String query) {
    if (query.isEmpty || source.isEmpty) {
      return [TextSpan(text: source)];
    }


    final queryLower = query.toLowerCase();
    final sourceLower = source.toLowerCase();
    
    if (!sourceLower.contains(queryLower)) {
      return [TextSpan(text: source)];
    }


    final matches = queryLower.allMatches(sourceLower).toList();
    int lastMatchEnd = 0;
    final List<TextSpan> children = [];
    
    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      
      if (match.start != lastMatchEnd) {
        children.add(TextSpan(text: source.substring(lastMatchEnd, match.start)));
      }
      
      final bool isCurrentMatch = i == _currentMatchIndex;
      
      children.add(TextSpan(
        text: source.substring(match.start, match.end),
        style: TextStyle(
          backgroundColor: isCurrentMatch 
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
          color: isCurrentMatch ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary,
          fontWeight: isCurrentMatch ? FontWeight.bold : FontWeight.w600,
        ),
      ));
      lastMatchEnd = match.end;
    }
    
    if (lastMatchEnd != source.length) {
      children.add(TextSpan(text: source.substring(lastMatchEnd)));
    }
    
    return children;
  }

  // Calculate responsive font size based on screen width
  double _getResponsiveFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth < 360) {
      return 16.0; // Small phones
    } else if (screenWidth < 400) {
      return 17.5; // Medium phones
    } else if (screenWidth < 600) {
      return 18.5; // Large phones
    } else if (screenWidth < 900) {
      return 20.0; // Small tablets
    } else {
      return 22.0; // Large tablets/desktop
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _slideAnimation.value) * 100),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 0,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                _buildDragHandle(),
                _buildHeader(context),
                Expanded(
                  child: _buildLyricsContent(),
                ),
              ],
            ),
            if (_showScrollToTop)
              Positioned(
                right: 16,
                bottom: 32,
                child: _buildScrollToTopButton(),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildDragHandle() {
    return Container(
      width: 48,
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }


  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Song info card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  // Back button
                  UIHelpers.buildIconButton(
                    context,
                    icon: Icons.arrow_back_rounded,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    tooltip: 'Back',
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  // Album art with actual image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: colorScheme.surfaceContainerHighest,
                      child: widget.picture != null
                          ? Image.memory(
                              widget.picture!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.music_note_rounded,
                                color: colorScheme.onSurfaceVariant,
                                size: 32,
                              ),
                            )
                          : Icon(
                              Icons.music_note_rounded,
                              color: colorScheme.onSurfaceVariant,
                              size: 32,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Song info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.artist,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _isLoadingNotifier,
                        builder: (context, isLoading, child) {
                          return UIHelpers.buildIconButton(
                            context,
                            icon: isLoading ? Icons.hourglass_empty_rounded : Icons.refresh_rounded,
                            onTap: isLoading ? () {} : _retryFetch,
                            tooltip: 'Refresh',
                            size: 24,
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      ValueListenableBuilder<bool>(
                        valueListenable: _isLoadingNotifier,
                        builder: (context, isLoading, child) {
                          if (isLoading) return const SizedBox.shrink();
                          return UIHelpers.buildIconButton(
                            context,
                            icon: Icons.copy_rounded,
                            onTap: _copyLyrics,
                            tooltip: 'Copy Lyrics',
                            size: 24,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Search bar below song info
          _buildSearchBar(colorScheme),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _searchFocusNode.hasFocus
              ? colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _updateMatchCount();
          });
        },
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search in lyrics...',
          hintStyle: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: _searchQuery.isNotEmpty 
                ? colorScheme.primary 
                : colorScheme.onSurfaceVariant,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_totalMatches > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_currentMatchIndex + 1}/$_totalMatches',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                        onPressed: _navigateToPreviousMatch,
                        tooltip: 'Previous',
                        color: colorScheme.primary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                        onPressed: _navigateToNextMatch,
                        tooltip: 'Next',
                        color: colorScheme.primary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _updateMatchCount();
                        });
                      },
                      color: colorScheme.onSurfaceVariant,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }


  Widget _buildLyricsContent() {
    final theme = Theme.of(context);
    final responsiveFontSize = _getResponsiveFontSize(context);
    
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      thickness: 6,
      radius: const Radius.circular(3),
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 24.0,
          bottom: 120.0,
        ),
        physics: const BouncingScrollPhysics(),
        child: ValueListenableBuilder<String>(
          valueListenable: _lyricsNotifier,
          builder: (context, lyrics, child) {
            return ValueListenableBuilder<bool>(
              valueListenable: _isLoadingNotifier,
              builder: (context, isLoading, child) {
                if (isLoading) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 120),
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Fetching lyrics...',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<String>(
                          valueListenable: _currentApiNotifier,
                          builder: (context, status, _) {
                            return Text(
                              status,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }
                
                if (lyrics.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: responsiveFontSize,
                        height: 2.0,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w400,
                      ),
                      children: _highlightOccurrences(lyrics, _searchQuery),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }


  Widget _buildScrollToTopButton() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return FloatingActionButton(
      onPressed: _scrollToTop,
      elevation: 0,
      highlightElevation: 0,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      mini: true,
      child: const Icon(Icons.arrow_upward_rounded, size: 20),
    );
  }
}
