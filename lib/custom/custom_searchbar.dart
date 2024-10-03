// lib/custom/custom_searchbar.dart

import 'package:flutter/material.dart';

class CustomSearchBar extends StatefulWidget implements PreferredSizeWidget {
  final String hintText;
  final Function(String) onChanged;
  final List<Widget>? actions;

  const CustomSearchBar({
    Key? key,
    required this.hintText,
    required this.onChanged,
    this.actions,
  }) : super(key: key);

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: InputBorder.none,
          hintStyle: const TextStyle(color: Colors.white70),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                )
              : null,
        ),
        style: const TextStyle(color: Colors.white),
        onChanged: (value) {
                    if (mounted) {
          setState(() {
            widget.onChanged(value);
          });
        }
        },
      ),
      actions: widget.actions,
    );
  }
}