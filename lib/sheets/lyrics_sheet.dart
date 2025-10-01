import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';

class LyricsSheet extends StatefulWidget {
  final String artist;
  final String title;

  const LyricsSheet({Key? key, required this.artist, required this.title}) : super(key: key);

  @override
  _LyricsSheetState createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  late AnimationController _controller;
  late Animation<double> _animation;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<String> _lyricsNotifier = ValueNotifier<String>('Loading...');
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _hasSyncedLyrics = ValueNotifier<bool>(false);
  final ValueNotifier<String> _currentApiNotifier = ValueNotifier<String>('');
  bool _showSyncedLyrics = false;
  String _syncedLyrics = '';
  String _plainLyrics = '';

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _lyricsNotifier.dispose();
    _isLoadingNotifier.dispose();
    _hasSyncedLyrics.dispose();
    _currentApiNotifier.dispose();
    super.dispose();
  }

  // Get realistic browser headers to avoid bot detection
  Map<String, String> _getBrowserHeaders() {
    final userAgents = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
    ];
    
    return {
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'cross-site',
      'User-Agent': userAgents[Random().nextInt(userAgents.length)],
      'Referer': 'https://www.google.com/',
      'Origin': 'https://www.google.com',
    };
  }

Future<void> _fetchLyrics() async {
  _isLoadingNotifier.value = true;
  _lyricsNotifier.value = 'Loading...';
  
  final encodedArtist = Uri.encodeComponent(widget.artist.trim());
  final encodedTitle = Uri.encodeComponent(widget.title.trim());
  
  // List of APIs to try in order with different approaches
  final apis = [
    {
      'name': 'Lyrist',
      'url': 'https://lyrist.vercel.app/api/$encodedArtist/$encodedTitle',
      'type': 'lyrist',
      'delay': 1000, // Add delay to avoid rate limiting
    },
    {
      'name': 'Lyrics API',
      'url': 'https://api.lyrics.ovh/v1/$encodedArtist/$encodedTitle',
      'type': 'lyricsovh',
      'delay': 0,
    },
    {
      'name': 'LRCLIB',
      'url': 'https://api.lrclib.net/api/get?artist=$encodedArtist&track=$encodedTitle',
      'type': 'lrclib',
      'delay': 0,
    },
    {
      'name': 'Lyrica API',
      'url': 'https://lyrica-api.vercel.app/api?artist=${widget.artist.trim()}&title=${widget.title.trim()}',
      'type': 'lyrica',
      'delay': 500,
    },
    {
      'name': 'Some-Random-API',
      'url': 'https://some-random-api.com/lyrics?title=${widget.title.trim()}&artist=${widget.artist.trim()}',
      'type': 'randomapi',
      'delay': 0,
    },
  ];

  bool success = false;
  String lastError = '';
  int attemptCount = 0;

  for (var api in apis) {
    if (success) break;
    attemptCount++;
    
    try {
      // Cast to String when accessing string values
      final String apiName = api['name'] as String;
      final String apiUrl = api['url'] as String;
      final String apiType = api['type'] as String;
      final int apiDelay = api['delay'] as int;
      
      print('🎵 Trying $apiName ($attemptCount/${apis.length}): $apiUrl');
      _currentApiNotifier.value = 'Trying $apiName ($attemptCount/${apis.length})...';
      
      // Add delay if specified to avoid rate limiting
      if (apiDelay > 0) {
        await Future.delayed(Duration(milliseconds: apiDelay));
      }
      
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: _getBrowserHeaders(),
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw TimeoutException('Request timed out after 12 seconds');
        },
      );
      
      print('📡 $apiName Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        success = await _parseApiResponse(response.body, apiType, apiName);
        if (success) {
          _currentApiNotifier.value = 'Loaded from $apiName';
          break;
        }
      } else if (response.statusCode == 403) {
        print('🚫 $apiName - 403: Blocked by security (bot protection)');
        lastError = '$apiName: Blocked by bot protection';
      } else if (response.statusCode == 404) {
        print('❌ $apiName - 404: Lyrics not found');
        lastError = '$apiName: Lyrics not found';
      } else if (response.statusCode == 429) {
        print('⏳ $apiName - 429: Rate limited');
        lastError = '$apiName: Rate limited - too many requests';
        // Add extra delay for rate limiting
        await Future.delayed(const Duration(seconds: 2));
      } else {
        print('❌ $apiName HTTP Error ${response.statusCode}');
        lastError = '$apiName: Server error (${response.statusCode})';
      }
    } on SocketException catch (e) {
      final String apiName = api['name'] as String;
      print('🔌 $apiName SocketException: ${e.message}');
      lastError = '$apiName: Network connection failed';
      continue;
    } on TimeoutException catch (e) {
      final String apiName = api['name'] as String;
      print('⏰ $apiName TimeoutException: ${e.message}');
      lastError = '$apiName: Request timed out';
      continue;
    } on FormatException catch (e) {
      final String apiName = api['name'] as String;
      print('📝 $apiName FormatException: ${e.message}');
      lastError = '$apiName: Invalid response format';
      continue;
    } catch (e) {
      final String apiName = api['name'] as String;
      print('❗ $apiName Unexpected error: $e');
      lastError = '$apiName: Unexpected error';
      continue;
    }
  }

  if (!success) {
    _currentApiNotifier.value = 'All APIs failed';
    _lyricsNotifier.value = '''No lyrics found after trying ${apis.length} sources.

Last error: $lastError

Tried sources:
• Lyrist (Bot protection issue)
• Lyrics.ovh (Original API)
• LRCLIB (Network issue)
• Lyrica API (Alternative)
• Some-Random-API (Backup)

Common issues:
• Bot protection blocking requests
• Network/DNS connectivity problems
• Song not in databases
• Rate limiting

Try:
• Check your internet connection
• Verify artist/song spelling
• Try again in a few minutes
• Search manually on lyrics websites''';
  }

  _isLoadingNotifier.value = false;
}

Future<bool> _parseApiResponse(String responseBody, String apiType, String apiName) async {
    try {
      switch (apiType) {
        case 'lyrist':
        case 'lyricsovh':
          return _parseLyristResponse(responseBody, apiName);
        case 'lrclib':
          return _parseLrclibResponse(responseBody, apiName);
        case 'lyrica':
          return _parseLyricaResponse(responseBody, apiName);
        case 'randomapi':
          return _parseRandomApiResponse(responseBody, apiName);
        default:
          return false;
      }
    } catch (e) {
      print('❌ Error parsing $apiName response: $e');
      return false;
    }
  }

  bool _parseLyristResponse(String responseBody, String apiName) {
    final data = json.decode(responseBody);
    final lyrics = data['lyrics'] ?? '';
    
    if (lyrics.isEmpty || 
        lyrics.toLowerCase().contains('not found') ||
        lyrics.toLowerCase().contains('error') ||
        lyrics.length < 10) {
      print('❌ $apiName: Empty or invalid response');
      return false;
    }
    
    _plainLyrics = lyrics;
    _syncedLyrics = '';
    _lyricsNotifier.value = _plainLyrics;
    _hasSyncedLyrics.value = false;
    print('✅ $apiName: Lyrics loaded successfully (${lyrics.length} characters)');
    return true;
  }

  bool _parseLrclibResponse(String responseBody, String apiName) {
    final data = json.decode(responseBody);
    
    _plainLyrics = data['plainLyrics'] ?? data['lyrics'] ?? '';
    _syncedLyrics = data['syncedLyrics'] ?? '';
    
    if (_plainLyrics.isEmpty || _plainLyrics.length < 10) {
      print('❌ $apiName: Empty lyrics response');
      return false;
    }
    
    _lyricsNotifier.value = _plainLyrics;
    _hasSyncedLyrics.value = _syncedLyrics.isNotEmpty;
    print('✅ $apiName: Lyrics loaded successfully');
    return true;
  }

  bool _parseLyricaResponse(String responseBody, String apiName) {
    final data = json.decode(responseBody);
    final lyrics = data['lyrics'] ?? data['lyric'] ?? '';
    
    if (lyrics.isEmpty || lyrics.length < 10) {
      print('❌ $apiName: Empty lyrics response');
      return false;
    }
    
    _plainLyrics = lyrics;
    _syncedLyrics = '';
    _lyricsNotifier.value = _plainLyrics;
    _hasSyncedLyrics.value = false;
    print('✅ $apiName: Lyrics loaded successfully');
    return true;
  }

  bool _parseRandomApiResponse(String responseBody, String apiName) {
    final data = json.decode(responseBody);
    final lyrics = data['lyrics'] ?? '';
    
    if (lyrics.isEmpty || lyrics.length < 10) {
      print('❌ $apiName: Empty lyrics response');
      return false;
    }
    
    _plainLyrics = lyrics;
    _syncedLyrics = '';
    _lyricsNotifier.value = _plainLyrics;
    _hasSyncedLyrics.value = false;
    print('✅ $apiName: Lyrics loaded successfully');
    return true;
  }

  Future<void> _retryFetch() async {
    await _fetchLyrics();
  }

  void _toggleLyricsType() {
    setState(() {
      _showSyncedLyrics = !_showSyncedLyrics;
      _lyricsNotifier.value = _showSyncedLyrics ? _syncedLyrics : _plainLyrics;
    });
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

    final matches = RegExp(RegExp.escape(query), caseSensitive: false).allMatches(source);
    int lastMatchEnd = 0;
    final List<TextSpan> children = [];
    
    for (var match in matches) {
      if (match.start != lastMatchEnd) {
        children.add(TextSpan(text: source.substring(lastMatchEnd, match.start)));
      }
      children.add(TextSpan(
        text: source.substring(match.start, match.end),
        style: TextStyle(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.3),
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _animation.value) * 100),
          child: Opacity(
            opacity: _animation.value,
            child: child,
          ),
        );
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 0,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildHeader(context),
            _buildControls(),
            Expanded(
              child: _buildLyricsContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.artist,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: _currentApiNotifier,
                      builder: (context, apiStatus, child) {
                        if (apiStatus.isEmpty) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            apiStatus,
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _isLoadingNotifier,
            builder: (context, isLoading, child) {
              return IconButton(
                icon: Icon(isLoading ? Icons.hourglass_empty : Icons.refresh_rounded),
                onPressed: isLoading ? null : _retryFetch,
                tooltip: 'Retry',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          SizedBox(
            height: 45,
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search in lyrics...',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[500],
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: _hasSyncedLyrics,
            builder: (context, hasSynced, child) {
              if (!hasSynced) return const SizedBox.shrink();
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Plain',
                    style: TextStyle(
                      color: !_showSyncedLyrics ? Theme.of(context).primaryColor : Colors.grey[500],
                      fontSize: 13,
                    ),
                  ),
                  Switch(
                    value: _showSyncedLyrics,
                    onChanged: (_) => _toggleLyricsType(),
                    activeColor: Theme.of(context).primaryColor,
                  ),
                  Text(
                    'Timed',
                    style: TextStyle(
                      color: _showSyncedLyrics ? Theme.of(context).primaryColor : Colors.grey[500],
                      fontSize: 13,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsContent() {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(
          left: 20.0,
          right: 20.0,
          top: 20.0,
          bottom: 100.0,
        ),
        physics: const BouncingScrollPhysics(),
        child: ValueListenableBuilder<String>(
          valueListenable: _lyricsNotifier,
          builder: (context, lyrics, child) {
            return Container(
              width: double.infinity,
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    letterSpacing: 0.2,
                  ),
                  children: _highlightOccurrences(lyrics, _searchQuery),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
