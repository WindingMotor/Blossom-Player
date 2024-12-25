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
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              isDense: true,
              helperText: helperText,
              helperStyle: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              helperMaxLines: 1,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ],
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
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  bottomPadding + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Metadata',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Update song information',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                          FilledButton.icon(
                            onPressed: () => _saveMetadata(context),
                            icon: const Icon(Icons.save_rounded, size: 20),
                            label: const Text('Save'),
                          ),
                        ],
                      ),
                    ),
                    // Form Fields
                    _buildTextField(
                      label: 'Title',
                      controller: _titleController,
                      helperText: 'Song title',
                    ),
                    _buildTextField(
                      label: 'Artist',
                      controller: _artistController,
                      helperText: 'Song artist or band name',
                    ),
                    _buildTextField(
                      label: 'Album',
                      controller: _albumController,
                      helperText: 'Album name',
                    ),
                    _buildTextField(
                      label: 'Year',
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      helperText: 'Release year',
                    ),
                    _buildTextField(
                      label: 'Genre',
                      controller: _genreController,
                      helperText: 'Music genre',
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}