part of '../nplayer.dart';

extension NPlayerSorting on NPlayer {
  // MARK: Search and Sort
  void setSearchQuery(String query) {
  _debounceTimer?.cancel();
  _searchQuery = query.toLowerCase();
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
    final fuse = Fuzzy(
      _allSongs,
      options: FuzzyOptions(
        keys: [
          WeightedKey(name: 'title', getter: (Music s) => s.title, weight: 80),
          WeightedKey(name: 'artist', getter: (Music s) => s.artist, weight: 40),
          WeightedKey(name: 'album', getter: (Music s) => s.album, weight: 20),
        ],
        threshold: 0.4,
      ),
    );
    _sortedSongs = fuse.search(_searchQuery).map((r) => r.item).toList();
  }
  _applySorting();
  _internalNotifyListeners();
}

void _applySorting() {
  // Sort logic remains the same
  _sortedSongs.sort((a, b) {
    int comparison;
    switch (_sortBy) {
      case 'title': comparison = a.title.compareTo(b.title); break;
      case 'artist': comparison = a.artist.compareTo(b.artist); break;
      case 'album': comparison = a.album.compareTo(b.album); break;
      case 'duration': comparison = a.duration.compareTo(b.duration); break;
      case 'folder': comparison = a.folderName.compareTo(b.folderName); break;
      case 'modified': comparison = b.lastModified.compareTo(a.lastModified); break;
      case 'year': 
          comparison = (int.tryParse(a.year) ?? 0).compareTo(int.tryParse(b.year) ?? 0); 
          break;
      case 'plays': 
          comparison = SongData.getPlayCount(b.path).compareTo(SongData.getPlayCount(a.path)); 
          break;
      case 'favorite': 
          comparison = (b.isFavorite ? 1 : 0).compareTo(a.isFavorite ? 1 : 0);
          if (comparison == 0) comparison = a.title.compareTo(b.title);
          break;
      default: comparison = a.title.compareTo(b.title);
    }
    return _sortAscending ? comparison : -comparison;
  });
}

void sortSongs({String? sortBy, bool? ascending}) {
  _sortBy = sortBy ?? _sortBy;
  _sortAscending = ascending ?? _sortAscending;
  _filterAndSortSongs(); // This will re-filter and apply the new sort
  Settings.setLibrarySongSort(_sortBy, _sortAscending);
}

Future<void> loadSortSettings() async {
  _sortBy = Settings.songSortBy;
  _sortAscending = Settings.songSortAscending;
  }
}
