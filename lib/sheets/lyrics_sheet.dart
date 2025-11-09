import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class LyricsSheet extends StatefulWidget {
  final String artist;
  final String title;

  const LyricsSheet({Key? key, required this.artist, required this.title}) : super(key: key);

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
  double _fontSize = 17.0;
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
      print('🎵 Fetching from LRCLIB: $apiUrl');
      
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: _getBrowserHeaders(),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out after 10 seconds');
        },
      );
      
      print('📡 LRCLIB Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String lyrics = data['plainLyrics'] ?? data['syncedLyrics'] ?? '';
        
        if (lyrics.isNotEmpty && lyrics.length >= 10) {
          _lyricsNotifier.value = lyrics.trim();
          _currentApiNotifier.value = '✓ LRCLIB';
          print('✅ LRCLIB: Lyrics loaded successfully (${lyrics.length} characters)');
          
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              _currentApiNotifier.value = '';
            }
          });
        } else {
          _showErrorMessage('LRCLIB returned empty lyrics for this song.');
        }
      } else if (response.statusCode == 404) {
        print('❌ LRCLIB - 404: Lyrics not found');
        _showErrorMessage('Lyrics not found in LRCLIB database.');
      } else {
        print('❌ LRCLIB - Error ${response.statusCode}');
        _showErrorMessage('LRCLIB server error (${response.statusCode})');
      }
    } on SocketException catch (e) {
      print('🔌 LRCLIB SocketException: ${e.message}');
      _showErrorMessage('Network connection failed. Check your internet connection.');
    } on TimeoutException catch (e) {
      print('⏰ LRCLIB TimeoutException: ${e.message}');
      _showErrorMessage('Request timed out. Please try again.');
    } on FormatException catch (e) {
      print('📝 LRCLIB FormatException: ${e.message}');
      _showErrorMessage('Invalid response format from LRCLIB.');
    } catch (e) {
      print('❗ LRCLIB Unexpected error: $e');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary, size: 20),
            const SizedBox(width: 12),
            const Text('Lyrics copied to clipboard'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
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
              ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
              : Theme.of(context).colorScheme.primary.withOpacity(0.25),
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
              color: colorScheme.shadow.withOpacity(0.3),
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
                _buildControls(),
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
        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
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
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              tooltip: 'Close',
              iconSize: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.artist,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<String>(
            valueListenable: _currentApiNotifier,
            builder: (context, apiStatus, child) {
              if (apiStatus.isEmpty) return const SizedBox.shrink();
              
              Color statusColor = colorScheme.primary;
              IconData statusIcon = Icons.info_outline;
              
              if (apiStatus.contains('Failed')) {
                statusColor = colorScheme.error;
                statusIcon = Icons.error_outline;
              } else if (apiStatus.contains('✓')) {
                statusColor = colorScheme.tertiary;
                statusIcon = Icons.check_circle_outline;
              }
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      apiStatus,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<bool>(
            valueListenable: _isLoadingNotifier,
            builder: (context, isLoading, child) {
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    isLoading ? Icons.hourglass_empty_rounded : Icons.refresh_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                  onPressed: isLoading ? null : _retryFetch,
                  tooltip: 'Refresh',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search in lyrics...',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 22,
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_currentMatchIndex + 1}/$_totalMatches',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
                              onPressed: _navigateToPreviousMatch,
                              tooltip: 'Previous',
                              color: colorScheme.primary,
                            ),
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                              onPressed: _navigateToNextMatch,
                              tooltip: 'Next',
                              color: colorScheme.primary,
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _updateMatchCount();
                              });
                            },
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildActionChip(
                    icon: Icons.text_decrease_rounded,
                    label: 'A-',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_fontSize > 14) _fontSize -= 1;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildActionChip(
                    icon: Icons.text_increase_rounded,
                    label: 'A+',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_fontSize < 24) _fontSize += 1;
                      });
                    },
                  ),
                ],
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _isLoadingNotifier,
                builder: (context, isLoading, child) {
                  if (isLoading) return const SizedBox.shrink();
                  return _buildActionChip(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    onTap: _copyLyrics,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSecondaryContainer,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsContent() {
    final theme = Theme.of(context);
    
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
          top: 8.0,
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
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 1500),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 0.8 + (value * 0.2),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary,
                                ),
                                strokeWidth: 3,
                              ),
                            );
                          },
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
                        fontSize: _fontSize,
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
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _scrollToTop,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}