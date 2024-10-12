import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LyricsSheet extends StatefulWidget {
  final String artist;
  final String title;

  const LyricsSheet({Key? key, required this.artist, required this.title}) : super(key: key);

  @override
  _LyricsSheetState createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> with SingleTickerProviderStateMixin {
  String _lyrics = 'Loading...';
  String _searchQuery = '';
  late AnimationController _controller;
  late Animation<double> _animation;
  final ScrollController _scrollController = ScrollController();

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
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLyrics() async {
    final encodedArtist = Uri.encodeComponent(widget.artist);
    final encodedTitle = Uri.encodeComponent(widget.title);
    final url = 'https://api.lyrics.ovh/v1/$encodedArtist/$encodedTitle';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _lyrics = data['lyrics'] ?? 'Lyrics not found.';
        });
      } else {
        setState(() {
          _lyrics = 'Failed to load lyrics.';
        });
      }
    } catch (e) {
      setState(() {
        _lyrics = 'Error: $e';
      });
    }
  }

  List<TextSpan> _highlightOccurrences(String source, String query) {
    if (query.isEmpty || !source.toLowerCase().contains(query.toLowerCase())) {
      return [TextSpan(text: source)];
    }
    final matches = RegExp(query, caseSensitive: false).allMatches(source);
    int lastMatchEnd = 0;
    final List<TextSpan> children = [];
    for (var match in matches) {
      if (match.start != lastMatchEnd) {
        children.add(TextSpan(text: source.substring(lastMatchEnd, match.start)));
      }
      children.add(TextSpan(
        text: source.substring(match.start, match.end),
        style: TextStyle(backgroundColor: Colors.yellow, color: Colors.black),
      ));
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd != source.length) {
      children.add(TextSpan(text: source.substring(lastMatchEnd, source.length)));
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
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            _buildHeader(context),
            _buildSearchBar(),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 16, height: 1.5, color: Theme.of(context).textTheme.bodyLarge?.color),
                      children: _highlightOccurrences(_lyrics, _searchQuery),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lyrics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.title} - ${widget.artist}',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildSearchBar() {
  return Center(
    child: SizedBox(
      width: MediaQuery.of(context).size.width * 0.8, 
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: SizedBox(
          height: 40.0,
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: TextStyle(fontSize: 14.0),
            decoration: InputDecoration(
              hintText: 'Search lyrics...',
              hintStyle: TextStyle(fontSize: 14.0),
              prefixIcon: Icon(
                Icons.search,
                size: 20.0,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}