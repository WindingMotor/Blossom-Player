/// Reusable search bar widget with integrated controls
///
/// Provides:
/// - Search functionality with clear button
/// - Optional sort/filter menu integration
/// - Optional quick action buttons (shuffle, settings)
/// - Optional custom trailing widget

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/nplayer.dart';

/// Search bar widget with integrated controls
///
/// Parameters:
/// - [searchController]: TextEditingController for search input
/// - [onSearchChanged]: Callback when search text changes
/// - [hintText]: Placeholder text for search input
/// - [onShowSortMenu]: Optional callback to show sort menu
/// - [onShuffle]: Optional callback for shuffle action
/// - [onSettings]: Optional callback for settings action
/// - [filterButtonKey]: Optional GlobalKey for positioning sort menu
/// - [showSortButton]: Whether to show sort button (default: true)
/// - [showShuffleButton]: Whether to show shuffle button (default: true)
/// - [showSettingsButton]: Whether to show settings button (default: true)
/// - [trailingWidget]: Optional custom widget to show at the end
/// - [bottomWidget]: Optional widget to show below the search bar
class OptimizedSearchBar extends StatefulWidget {
  final TextEditingController searchController;
  final Function(String) onSearchChanged;
  final String hintText;
  final VoidCallback? onShowSortMenu;
  final VoidCallback? onShuffle;
  final VoidCallback? onSettings;
  final GlobalKey? filterButtonKey;
  final bool showSortButton;
  final bool showShuffleButton;
  final bool showSettingsButton;
  final Widget? trailingWidget;
  final Widget? bottomWidget;

  const OptimizedSearchBar({
    Key? key,
    required this.searchController,
    required this.onSearchChanged,
    this.hintText = 'Search...',
    this.onShowSortMenu,
    this.onShuffle,
    this.onSettings,
    this.filterButtonKey,
    this.showSortButton = true,
    this.showShuffleButton = true,
    this.showSettingsButton = true,
    this.trailingWidget,
    this.bottomWidget,
  }) : super(key: key);

  @override
  State<OptimizedSearchBar> createState() => _OptimizedSearchBarState();
}

class _OptimizedSearchBarState extends State<OptimizedSearchBar> {
  final FocusNode _searchFocusNode = FocusNode();
  late bool _hadSearchText;

  @override
  void initState() {
    super.initState();
    _hadSearchText = widget.searchController.text.isNotEmpty;
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant OptimizedSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_onSearchChanged);
      _hadSearchText = widget.searchController.text.isNotEmpty;
      widget.searchController.addListener(_onSearchChanged);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final hasText = widget.searchController.text.isNotEmpty;
    if (_hadSearchText && !hasText) {
      _searchFocusNode.unfocus();
    }
    _hadSearchText = hasText;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NPlayer>(
      builder: (context, player, child) {
        final currentSort = _capitalize(player.sortBy);
        final sortDirection = player.sortAscending ? '↑' : '↓';

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context)
                    .colorScheme
                    .shadow
                    .withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: widget.searchController,
                        focusNode: _searchFocusNode,
                        onChanged: widget.onSearchChanged,
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                  ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    // Clear search button
                    if (widget.searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          widget.searchController.clear();
                          widget.onSearchChanged('');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.clear_rounded,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 20),

                    // Custom trailing widget (if provided)
                    if (widget.trailingWidget != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: widget.trailingWidget!,
                      ),

                    // Filter/Sort button (if enabled and no trailing widget)
                    if (widget.trailingWidget == null &&
                        widget.showSortButton &&
                        widget.onShowSortMenu != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Material(
                          key: widget.filterButtonKey,
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onShowSortMenu,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Tooltip(
                                message:
                                    'Sorted by $currentSort $sortDirection',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 16,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      player.sortAscending
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      size: 16,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Shuffle button (if enabled and no trailing widget)
                    if (widget.trailingWidget == null &&
                        widget.showShuffleButton &&
                        widget.onShuffle != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onShuffle,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.shuffle_rounded,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Settings button (if enabled and no trailing widget)
                    if (widget.trailingWidget == null &&
                        widget.showSettingsButton &&
                        widget.onSettings != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onSettings,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.settings_rounded,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Optional bottom widget
              if (widget.bottomWidget != null) widget.bottomWidget!,
            ],
          ),
        );
      },
    );
  }

  /// Capitalizes the first letter of a string
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
