/// UI Helper utilities for common UI components and operations
/// This file contains reusable UI building blocks to reduce code duplication

import 'package:flutter/material.dart';

class UIHelpers {
  /// Builds a sort button with tune icon and ascending/descending indicator
  static Widget buildSortButton(
    BuildContext context, {
    required VoidCallback onTap,
    required bool sortAscending,
    String? tooltip,
    Key? key,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Tooltip(
            message: tooltip ?? 'Sort',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 2),
                Icon(
                  sortAscending ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds an icon button with consistent styling
  static Widget buildIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    double size = 18,
    Color? color,
    double padding = 6,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(padding),
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(
              icon,
              size: size,
              color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds an icon button with primary background
  static Widget buildPrimaryIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    double size = 18,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(
              icon,
              size: size,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a popup menu item for sort options
  static PopupMenuItem<String> buildPopupMenuItem(
    BuildContext context, {
    required String value,
    required IconData icon,
    required bool isActive,
    String? displayText,
  }) {
    final text = displayText ?? _capitalize(value);
    
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isActive ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          if (isActive) ...[
            const Spacer(),
            Icon(
              Icons.check_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  /// Shows a positioned sort menu relative to a button
  static Future<String?> showSortMenu(
    BuildContext context, {
    required GlobalKey buttonKey,
    required List<PopupMenuEntry<String>> items,
  }) {
    final RenderBox? buttonBox = buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null) return Future.value(null);
    
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset buttonPosition = buttonBox.localToGlobal(Offset.zero, ancestor: overlay);
    final Size screenSize = MediaQuery.of(context).size;
    
    // Calculate if menu should appear on left or right side of button
    const double menuWidth = 200.0;
    final bool showOnLeft = (buttonPosition.dx + menuWidth) > screenSize.width;
    
    // Position menu to the right of button by default, or left if it would overflow
    final double left = showOnLeft 
        ? buttonPosition.dx - menuWidth + buttonBox.size.width 
        : buttonPosition.dx;
    final double top = buttonPosition.dy + buttonBox.size.height + 8;
    final double right = showOnLeft 
        ? screenSize.width - buttonPosition.dx - buttonBox.size.width
        : screenSize.width - buttonPosition.dx - menuWidth;
    
    final RelativeRect position = RelativeRect.fromLTRB(
      left,
      top,
      right,
      0,
    );

    return showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: items,
    );
  }

  /// Shows a positioned menu at specific coordinates
  static Future<String?> showPositionedMenu(
    BuildContext context, {
    required double left,
    required double top,
    required List<PopupMenuEntry<String>> items,
  }) {
    return showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(left, top, 20, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: items,
    );
  }

  /// Calculates year range from a list of songs
  static String getYearRange(List<dynamic> items, String Function(dynamic) getYear) {
    if (items.length == 1) {
      return getYear(items.first);
    }

    final years = items
        .map((item) => getYear(item))
        .where((year) => year.isNotEmpty)
        .toList();
    
    if (years.isEmpty) return '';
    
    final minYear = years.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
    final maxYear = years.reduce((a, b) => a.compareTo(b) > 0 ? a : b);

    return minYear == maxYear ? minYear : '$minYear - $maxYear';
  }

  /// Builds an empty state widget
  static Widget buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 24),
            action,
          ],
        ],
      ),
    );
  }

  /// Checks if current platform is desktop
  static bool isDesktopPlatform(BuildContext context) {
    return [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    ].contains(Theme.of(context).platform);
  }

  /// Creates a standard animation controller with fade animation
  static AnimationController createFadeAnimationController(TickerProvider vsync) {
    return AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: vsync,
    );
  }

  /// Creates a fade animation from an animation controller
  static Animation<double> createFadeAnimation(AnimationController controller) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeIn),
    );
  }

  /// Capitalizes the first letter of a string
  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Capitalizes the first letter of a string (public version)
  static String capitalize(String s) {
    return _capitalize(s);
  }
}

/// Extension methods for String
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}