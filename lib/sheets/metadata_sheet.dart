import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../audio/nplayer.dart';
import 'package:provider/provider.dart';

class MetadataSheet extends StatefulWidget {
  final Music song;

  const MetadataSheet({
    Key? key,
    required this.song,
  }) : super(key: key);

  @override
  _MetadataSheetState createState() => _MetadataSheetState();
}

class _MetadataSheetState extends State<MetadataSheet> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;
  late TextEditingController _yearController;
  late TextEditingController _genreController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist);
    _albumController = TextEditingController(text: widget.song.album);
    _yearController = TextEditingController(text: widget.song.year?.toString() ?? '');
    _genreController = TextEditingController(text: widget.song.genre);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _yearController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  void _saveMetadata(BuildContext context) {
    final player = Provider.of<NPlayer>(context, listen: false);
    player.updateSongMetadata(
      widget.song,
      {
        'title': _titleController.text,
        'artist': _artistController.text,
        'album': _albumController.text,
        'year': _yearController.text,
        'genre': _genreController.text,
      },
    );
    Navigator.pop(context);
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 600;
    
    return Container(
      width: isDesktop ? screenSize.width * 0.4 : screenSize.width,
      constraints: const BoxConstraints(
        maxWidth: 600,
        minWidth: 300,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: EdgeInsets.symmetric(
              vertical: isDesktop ? 12 : 8,
            ),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : 16,
              isDesktop ? 16 : 8,
              isDesktop ? 24 : 16,
              bottomPadding + (isDesktop ? 24 : 16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Metadata',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: isDesktop ? 24 : 20,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      iconSize: isDesktop ? 28 : 24,
                      onPressed: () => _saveMetadata(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Form Fields
                _buildTextField(
                  label: 'Title',
                  controller: _titleController,
                ),
                _buildTextField(
                  label: 'Artist',
                  controller: _artistController,
                ),
                _buildTextField(
                  label: 'Album',
                  controller: _albumController,
                ),
                _buildTextField(
                  label: 'Year',
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                _buildTextField(
                  label: 'Genre',
                  controller: _genreController,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
