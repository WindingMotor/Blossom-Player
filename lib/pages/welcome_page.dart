import 'package:flutter/material.dart';
import 'package:blossom/tools/settings.dart';

class WelcomePage extends StatefulWidget {
  final VoidCallback onDismiss;

  const WelcomePage({
    super.key, 
    required this.onDismiss,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // Define pages in a list to ensure consistency
  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Welcome to Blossom',
      'description': 'Your modern, open-source music player for local audio files',
      'icon': Icons.music_note,
      'bullets': [
        'Simple and beautiful interface',
        'Support for MP3 and FLAC files',
        'Currently in beta development',
        'Available on iOS, Android, and Desktop',
      ],
    },
    {
      'title': 'Organize Your Music',
      'description': 'Multiple ways to browse and organize your music collection',
      'icon': Icons.library_music,
      'bullets': [
        'View by albums, artists, or songs',
        'Create and manage custom playlists',
        'Smart search and filtering',
        'Fuzzy search for finding songs quickly',
      ],
    },
    {
      'title': 'Companion App',
      'description': 'Download music directly using the Blossom Companion',
      'icon': Icons.download,
      'bullets': [
        'Integrated with spotDL for desktop',
        'Easy music downloading and organization',
        'Automatic metadata handling',
        'Direct integration with your library',
      ],
    },
    {
      'title': 'Customizable Experience',
      'description': 'Make Blossom yours with extensive customization options',
      'icon': Icons.palette,
      'bullets': [
        'Multiple theme options including OLED dark mode',
        'Customizable playback settings',
        'Playlist artwork customization',
        'Adjustable audio settings',
      ],
    },
    {
      'title': 'Coming Soon',
      'description': 'Exciting features in development',
      'icon': Icons.upcoming,
      'bullets': [
        'Background playback optimization',
        'Whisper audio-to-text for lyrics',
        'Local LLM for song organization',
        'Cloud service integration',
      ],
    },
    {
      'title': 'Open Source',
      'description': 'Blossom is free and open source software',
      'icon': Icons.code,
      'bullets': [
        'Available on GitHub',
        'Community-driven development',
        'Transparent development process',
        'Contributions welcome',
      ],
    },
    {
      'title': 'Beta Version',
      'description': 'Thank you for testing Blossom',
      'icon': Icons.science,
      'bullets': [
        'TestFlight coming soon for iOS',
        'Please report any bugs you find',
        'Your feedback helps improve Blossom',
        'Join our community for updates',
      ],
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _dismissAndNeverShowAgain() {
    Settings.setHasSeenWelcomePage(true);
    widget.onDismiss();
  }

  Widget _buildPageIndicator() {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(_pages.length, (index) {
          return Container(
            width: 8.0,
            height: 8.0,
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentPage == index
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWelcomePage(String title, String description, IconData icon, {List<String>? bulletPoints}) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 100,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 30),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            textAlign: TextAlign.center,
          ),
          if (bulletPoints != null) ...[
            const SizedBox(height: 20),
            ...bulletPoints.map((point) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 20.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                  )),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: _pages.map((pageData) => _buildWelcomePage(
                  pageData['title'] as String,
                  pageData['description'] as String,
                  pageData['icon'] as IconData,
                  bulletPoints: (pageData['bullets'] as List<String>),
                )).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                children: [
                  _buildPageIndicator(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (_currentPage != 0)
                        TextButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.ease,
                            );
                          },
                          child: const Text('Previous'),
                        ),
                      _currentPage == _pages.length - 1
                          ? ElevatedButton(
                              onPressed: _dismissAndNeverShowAgain,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                              child: const Text('Get Started'),
                            )
                          : TextButton(
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.ease,
                                );
                              },
                              child: const Text('Next'),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}