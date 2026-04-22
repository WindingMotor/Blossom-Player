/// Social Page - View what friends are listening to

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';
import '../tools/settings.dart';
import '../tools/ui_helpers.dart';
import '../custom/search_bar.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({Key? key}) : super(key: key);

  @override
  _SocialPageState createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addFriendController = TextEditingController();
  
  List<String> _friends = [];
  final Map<String, PublicUserStatus?> _statusCache = {};
  
  Timer? _autoRefreshTimer;
  bool _isRefreshing = false;
  
  @override
  void initState() {
    super.initState();
    _animationController = UIHelpers.createFadeAnimationController(this);
    _fadeAnimation = UIHelpers.createFadeAnimation(_animationController);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      _loadFriends();
      _startAutoRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    _addFriendController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (mounted && !_isRefreshing) {
        _refreshAllStatuses(silent: true);
      }
    });
  }

  Future<void> _loadFriends() async {
    await Settings.loadFriendsList();
    setState(() {
      _friends = List.from(Settings.friendsList);
    });
    if (_friends.isNotEmpty) {
      _refreshAllStatuses();
    }
  }

  Future<void> _refreshAllStatuses({bool silent = false}) async {
    if (_friends.isEmpty) return;
    
    if (!silent) {
      setState(() => _isRefreshing = true);
    }
    
    final player = context.read<NPlayer>();
    
    // Fetch all friend statuses
    for (final uuid in _friends) {
      try {
        final status = await player.fetchUserStatus(uuid);
        if (mounted) {
          setState(() {
            _statusCache[uuid] = status;
          });
        }
      } catch (e) {
        print('Error fetching status for $uuid: $e');
      }
    }
    
    if (!silent && mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  void _showAddFriendDialog() {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Friend'),
        content: TextField(
          controller: _addFriendController,
          decoration: InputDecoration(
            labelText: 'Friend\'s User ID',
            hintText: 'user-1234567890-1234',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: Icon(Icons.person_add_rounded),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
          ),
          autofocus: true,
          onSubmitted: (_) => _addFriend(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _addFriendController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _addFriend,
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addFriend() async {
    final uuid = _addFriendController.text.trim();

    if (uuid.isEmpty) {
      _addFriendController.clear();
      Navigator.pop(context);
      return;
    }

    if (!uuid.startsWith('user-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid User ID format')),
      );
      return;
    }

    if (_friends.contains(uuid)) {
      _addFriendController.clear();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend already added')),
      );
      return;
    }

    await Settings.addFriend(uuid);
    if (!mounted) return;

    _addFriendController.clear();
    setState(() {
      _friends = List.from(Settings.friendsList);
    });

    Navigator.pop(context);
    _refreshAllStatuses();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend added!')),
    );
  }

  void _removeFriend(String uuid) async {
    await Settings.removeFriend(uuid);
    if (!mounted) return;
    setState(() {
      _friends = List.from(Settings.friendsList);
      _statusCache.remove(uuid);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend removed')),
    );
  }

  void _copyOwnUuid() async {
    final player = context.read<NPlayer>();
    await Clipboard.setData(ClipboardData(text: player.userUuid));
    HapticFeedback.mediumImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Your User ID copied!')),
    );
  }

  Widget _buildTrailingButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isRefreshing)
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        
        UIHelpers.buildPrimaryIconButton(
          context,
          icon: Icons.person_add_rounded,
          onTap: _showAddFriendDialog,
          tooltip: 'Add Friend',
        ),
        
        const SizedBox(width: 8),
        
        UIHelpers.buildIconButton(
          context,
          icon: Icons.share_rounded,
          onTap: _copyOwnUuid,
          tooltip: 'Share ID',
        ),
      ],
    );
  }

  Widget _buildCompactStatusCard() {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        final currentSong = player.getCurrentSong();
        final isSharing = player.isSharingEnabled;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        
        return Container(
          margin: EdgeInsets.fromLTRB(8, 8, 8, 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Status icon
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSharing 
                      ? colorScheme.primary.withOpacity(0.15)
                      : colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isSharing ? Icons.public_rounded : Icons.public_off_rounded,
                  color: isSharing ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  size: 18,
                ),
              ),
              SizedBox(width: 12),
              
              // Status text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isSharing ? 'Sharing Enabled' : 'Private',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (isSharing && player.isPlaying && currentSong != null)
                      Text(
                        '${currentSong.title}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              
              // Toggle
              Switch(
                value: isSharing,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  player.togglePublicSharing(value);
                },
                activeColor: colorScheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFriendsList() {
    if (_friends.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 120),
          child: UIHelpers.buildEmptyState(
            context,
            icon: Icons.people_outline_rounded,
            title: 'No friends yet',
            subtitle: 'Add friends to see their music',
            action: FilledButton.icon(
              onPressed: _showAddFriendDialog,
              icon: Icon(Icons.person_add_rounded, size: 18),
              label: Text('Add Friend'),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshAllStatuses(),
      child: ListView.builder(
        padding: EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 120),
        itemCount: _friends.length,
        itemBuilder: (context, index) => _buildCompactFriendCard(_friends[index]),
      ),
    );
  }

  Widget _buildCompactFriendCard(String friendUuid) {
    final status = _statusCache[friendUuid];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOnline = status?.isOnline == true;
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
leading: Stack(
  children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: status?.albumArt != null
            ? Image.memory(
                base64Decode(status!.albumArt!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: colorScheme.surface,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              )
            : Container(
                color: colorScheme.surface,
                child: Icon(
                  isOnline ? Icons.music_note_rounded : Icons.person_outline_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
      ),
    ),
    if (isOnline)
      Positioned(
        right: -2,
        top: -2,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.surface, width: 2),
          ),
        ),
      ),
  ],
),

        title: Text(
          status?.username ?? '${friendUuid.substring(0, friendUuid.length.clamp(0, 18))}...',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: status == null
            ? Text('Loading...', style: TextStyle(fontSize: 11))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOnline && status.currentSong != null) ...[
                    Text(
                      status.currentSong!,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (status.currentArtist != null)
                      Text(
                        status.currentArtist!,
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ] else
                    Text(
                      status.displayText + ' • ' + status.lastSeenAgo,
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, size: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Refresh', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.person_remove_rounded, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remove', style: TextStyle(color: Colors.red, fontSize: 13)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            HapticFeedback.selectionClick();
            if (value == 'refresh') {
              _statusCache.remove(friendUuid);
              _refreshAllStatuses();
            } else if (value == 'remove') {
              _removeFriend(friendUuid);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.1),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              OptimizedSearchBar(
                searchController: _searchController,
                onSearchChanged: (value) {},
                trailingWidget: _buildTrailingButtons(),
              ),
              
              _buildCompactStatusCard(),
              
              if (_friends.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: Row(
                    children: [
                      Icon(Icons.people_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      SizedBox(width: 6),
                      Text(
                        'Friends (${_friends.length})',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Auto-refreshing',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              
              Expanded(child: _buildFriendsList()),
            ],
          ),
        ),
      ),
    );
  }
}
