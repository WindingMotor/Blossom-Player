part of '../nplayer.dart';

extension NPlayerSorting on NPlayer {
  // MARK: Search and Sort
  void setSearchQuery(String query) {
    _debounceTimer?.cancel();
    _searchQuery = query.trim().toLowerCase();
    _debounceTimer = Timer(_debounceDuration, _filterAndSortSongs);
    _internalNotifyListeners();
  }

  void _filterAndSortSongs() {
    if (_searchQuery.isEmpty) {
      _sortedSongs = List.from(_allSongs);
      if (_sortBy == 'favorite') {
        _sortedSongs = _sortedSongs.where((song) => song.isFavorite).toList();
      }
    } else {
      _sortedSongs = _performSmartSearch(_searchQuery);
    }
    _applySorting();
    _internalNotifyListeners();
  }

  List<Music> _performSmartSearch(String query) {
    final searchTerms = _parseSearchQuery(query);
    
    // Multi-stage search approach
    List<Music> results = [];
    
    // Stage 1: Exact matches (highest priority)
    results.addAll(_findExactMatches(searchTerms));
    
    // Stage 2: Prefix matches
    final remainingSongs = _allSongs.where((song) => !results.contains(song)).toList();
    results.addAll(_findPrefixMatches(remainingSongs, searchTerms));
    
    // Stage 3: Fuzzy search for remaining songs
    final stillRemaining = _allSongs.where((song) => !results.contains(song)).toList();
    results.addAll(_performFuzzySearch(stillRemaining, query));
    
    return results;
  }

  SearchTerms _parseSearchQuery(String query) {
    final terms = <String>[];
    final artistFilter = <String>[];
    final albumFilter = <String>[];
    final yearFilter = <String>[];
    
    // Parse special search operators
    final words = query.split(' ');
    
    for (final word in words) {
      if (word.startsWith('artist:')) {
        artistFilter.add(word.substring(7).toLowerCase());
      } else if (word.startsWith('album:')) {
        albumFilter.add(word.substring(6).toLowerCase());
      } else if (word.startsWith('year:')) {
        yearFilter.add(word.substring(5));
      } else if (word.isNotEmpty) {
        terms.add(word);
      }
    }
    
    return SearchTerms(
      generalTerms: terms,
      artistFilter: artistFilter,
      albumFilter: albumFilter,
      yearFilter: yearFilter,
    );
  }

  List<Music> _findExactMatches(SearchTerms searchTerms) {
    final results = <Music>[];
    final queryString = searchTerms.generalTerms.join(' ');
    
    for (final song in _allSongs) {
      bool matches = true;
      
      // Check filters first
      if (searchTerms.artistFilter.isNotEmpty) {
        matches = searchTerms.artistFilter.any((filter) => 
          song.artist.toLowerCase().contains(filter));
      }
      
      if (matches && searchTerms.albumFilter.isNotEmpty) {
        matches = searchTerms.albumFilter.any((filter) => 
          song.album.toLowerCase().contains(filter));
      }
      
      if (matches && searchTerms.yearFilter.isNotEmpty) {
        matches = searchTerms.yearFilter.any((filter) => 
          song.year.contains(filter));
      }
      
      // Check general terms
      if (matches && searchTerms.generalTerms.isNotEmpty) {
        final titleLower = song.title.toLowerCase();
        final artistLower = song.artist.toLowerCase();
        final albumLower = song.album.toLowerCase();
        
        // Exact title match (highest priority)
        if (titleLower == queryString) {
          results.insert(0, song);
          continue;
        }
        
        // All terms must be found somewhere
        matches = searchTerms.generalTerms.every((term) =>
          titleLower.contains(term) ||
          artistLower.contains(term) ||
          albumLower.contains(term)
        );
      }
      
      if (matches && !results.contains(song)) {
        results.add(song);
      }
    }
    
    return results;
  }

  List<Music> _findPrefixMatches(List<Music> songs, SearchTerms searchTerms) {
    final results = <Music>[];
    
    if (searchTerms.generalTerms.isEmpty) return results;
    
    final queryString = searchTerms.generalTerms.join(' ');
    
    for (final song in songs) {
      final titleLower = song.title.toLowerCase();
      final artistLower = song.artist.toLowerCase();
      
      // Title starts with query
      if (titleLower.startsWith(queryString)) {
        results.insert(0, song);
        continue;
      }
      
      // Artist starts with query
      if (artistLower.startsWith(queryString)) {
        results.add(song);
        continue;
      }
      
      // Any word in title starts with first search term
      final titleWords = titleLower.split(' ');
      if (titleWords.any((word) => word.startsWith(searchTerms.generalTerms.first))) {
        results.add(song);
      }
    }
    
    return results;
  }

  List<Music> _performFuzzySearch(List<Music> songs, String query) {
    if (songs.isEmpty) return [];
    
    final fuse = Fuzzy(
      songs,
      options: FuzzyOptions(
        keys: [
          WeightedKey(name: 'title', getter: (Music s) => s.title, weight: 100),
          WeightedKey(name: 'artist', getter: (Music s) => s.artist, weight: 80),
          WeightedKey(name: 'album', getter: (Music s) => s.album, weight: 60),
          WeightedKey(name: 'folderName', getter: (Music s) => s.folderName, weight: 30),
        ],
        threshold: 0.35, // Slightly more permissive
        distance: 100,
        minMatchCharLength: 2,
        shouldSort: true,
      ),
    );
    
    final fuzzyResults = fuse.search(query);
    
    // Filter and sort by relevance score
    return fuzzyResults
        .where((result) => result.score < 0.6) // Only good matches
        .map((result) => result.item)
        .toList();
  }

  void _applySorting() {
    // Enhanced sorting with search relevance consideration
    _sortedSongs.sort((a, b) {
      // If we have a search query, prioritize search relevance
      if (_searchQuery.isNotEmpty) {
        final aRelevance = _calculateSearchRelevance(a, _searchQuery);
        final bRelevance = _calculateSearchRelevance(b, _searchQuery);
        
        // If relevance is significantly different, use that
        if ((aRelevance - bRelevance).abs() > 10) {
          return bRelevance.compareTo(aRelevance); // Higher relevance first
        }
      }
      
      // Apply normal sorting
      int comparison;
      switch (_sortBy) {
        case 'title': 
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase()); 
          break;
        case 'artist': 
          comparison = a.artist.toLowerCase().compareTo(b.artist.toLowerCase()); 
          break;
        case 'album': 
          comparison = a.album.toLowerCase().compareTo(b.album.toLowerCase()); 
          break;
        case 'duration': 
          comparison = a.duration.compareTo(b.duration); 
          break;
        case 'folder': 
          comparison = a.folderName.toLowerCase().compareTo(b.folderName.toLowerCase()); 
          break;
        case 'modified': 
          comparison = b.lastModified.compareTo(a.lastModified); 
          break;
        case 'year': 
          comparison = (int.tryParse(b.year) ?? 0).compareTo(int.tryParse(a.year) ?? 0); 
          break;
        case 'plays': 
          comparison = SongData.getPlayCount(b.path).compareTo(SongData.getPlayCount(a.path)); 
          break;
        case 'favorite': 
          comparison = (b.isFavorite ? 1 : 0).compareTo(a.isFavorite ? 1 : 0);
          if (comparison == 0) {
            comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }
          break;
        case 'relevance':
          if (_searchQuery.isNotEmpty) {
            comparison = _calculateSearchRelevance(b, _searchQuery)
                .compareTo(_calculateSearchRelevance(a, _searchQuery));
          } else {
            comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }
          break;
        default: 
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  int _calculateSearchRelevance(Music song, String query) {
    final queryLower = query.toLowerCase();
    final titleLower = song.title.toLowerCase();
    final artistLower = song.artist.toLowerCase();
    final albumLower = song.album.toLowerCase();
    
    int score = 0;
    
    // Exact title match - highest score
    if (titleLower == queryLower) score += 1000;
    
    // Title starts with query
    if (titleLower.startsWith(queryLower)) score += 800;
    
    // Title contains query
    if (titleLower.contains(queryLower)) score += 600;
    
    // Artist exact match
    if (artistLower == queryLower) score += 700;
    
    // Artist starts with query
    if (artistLower.startsWith(queryLower)) score += 500;
    
    // Artist contains query
    if (artistLower.contains(queryLower)) score += 300;
    
    // Album matches
    if (albumLower.contains(queryLower)) score += 200;
    
    // Word boundary matches (whole words)
    final queryWords = queryLower.split(' ');
    final titleWords = titleLower.split(' ');
    final artistWords = artistLower.split(' ');
    
    for (final queryWord in queryWords) {
      if (titleWords.any((word) => word.startsWith(queryWord))) score += 400;
      if (artistWords.any((word) => word.startsWith(queryWord))) score += 200;
    }
    
    // Bonus for favorite songs
    if (song.isFavorite) score += 50;
    
    // Bonus for frequently played songs
    final playCount = SongData.getPlayCount(song.path);
    score += (playCount * 2).clamp(0, 100);
    
    return score;
  }

  void sortSongs({String? sortBy, bool? ascending}) {
    _sortBy = sortBy ?? _sortBy;
    _sortAscending = ascending ?? _sortAscending;
    _filterAndSortSongs();
    Settings.setLibrarySongSort(_sortBy, _sortAscending);
  }

  Future<void> loadSortSettings() async {
    _sortBy = Settings.songSortBy;
    _sortAscending = Settings.songSortAscending;
  }
}

// Helper class for parsed search terms
class SearchTerms {
  final List<String> generalTerms;
  final List<String> artistFilter;
  final List<String> albumFilter;
  final List<String> yearFilter;
  
  SearchTerms({
    required this.generalTerms,
    required this.artistFilter,
    required this.albumFilter,
    required this.yearFilter,
  });
}