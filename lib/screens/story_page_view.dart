// screens/story_view_page.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
// import 'package:video_player/video_player.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:async';

import '../sql.dart'; // Adjust path

// --- Theme Colors ---
const Color _backgroundColor = Color(0xFF121212);
const Color _accentColor = Color(0xFFE85D5D);
const Color _primaryTextColor = Colors.white;
const Color _secondaryTextColor = Colors.white70;
const Color _placeholderColor = Colors.grey;
// ---

class StoryViewPage extends StatefulWidget {
  final int userId;
  final String? username;
  final String? profilePicUrl;

  const StoryViewPage({
    super.key,
    required this.userId,
    this.username,
    this.profilePicUrl,
  });

  @override
  _StoryViewPageState createState() => _StoryViewPageState();
}

class _StoryViewPageState extends State<StoryViewPage> with TickerProviderStateMixin {
  final PostgresDB db = PostgresDB();
  List<Map<String, dynamic>> _stories = [];
  bool _isLoading = true;
  String? _error;

  String? _displayUsername;
  String? _displayProfilePicUrl;

  PageController _pageController = PageController();
  AnimationController? _animationController;
  int _currentIndex = 0;

  // **** NEW: Keep track of timers that have been started ****
  final Set<int> _timersStartedIndices = {};
  // VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _displayUsername = widget.username;
    _displayProfilePicUrl = widget.profilePicUrl;
    _fetchData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController?.dispose();
    // _videoController?.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    // ... (fetch logic remains the same as previous version) ...
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      final results = await Future.wait([
        db.getStoriesForUser(widget.userId),
        if (_displayUsername == null || _displayProfilePicUrl == null)
          db.getUserById(widget.userId)
        else
          Future.value(null)
      ]);

      if (!mounted) return;

      final fetchedStories = results[0] as List<Map<String, dynamic>>;
      final fetchedUser = results[1] as Map<String, dynamic>?;

      if (fetchedUser != null) {
        _displayUsername = fetchedUser['username'] as String?;
        _displayProfilePicUrl = fetchedUser['profile_pic_url'] as String?;
      }

      if (fetchedStories.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = "No stories found."; // Use localization
          _stories = [];
        });
        return;
      }

      setState(() {
        _stories = fetchedStories;
        _isLoading = false;
        _displayUsername ??= 'User';
      });

      // **** Prepare the timer for the first story, but DON'T start it ****
      _prepareStoryTimer(0);

    } catch (e) {
      print("Error fetching story data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to load stories."; // Use localization
        });
      }
    }
  }

  // Renamed: Prepares timer but doesn't start it
  void _prepareStoryTimer(int index) {
    if (index < 0 || index >= _stories.length || !mounted) return;

    _animationController?.dispose(); // Dispose previous one first
    const storyDuration = Duration(seconds: 5); // Or get duration based on content

    _animationController = AnimationController(vsync: this, duration: storyDuration)
      ..addListener(() { // Listener to update progress bar
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) { // Listener for when timer completes
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });

    // *** DO NOT CALL _animationController!.forward() here ***
  }

  // Actual function to start the timer - called from imageBuilder
  void _triggerTimerStart(int index) {
    if (!mounted || _animationController == null || _timersStartedIndices.contains(index)) {
      return; // Don't start if already started or controller not ready
    }
    print("Starting timer for index $index");
    _timersStartedIndices.add(index);
    _animationController!.forward();
  }


  void _onPageChanged(int index) {
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
    });
    // Prepare the timer for the new page. It will be started by imageBuilder.
    _prepareStoryTimer(index);
  }

  void _nextStory() {
    if (!mounted) return;
    if (_currentIndex < _stories.length - 1) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 1),
          curve: Curves.easeInOut,
        );
        // _onPageChanged will handle preparing the next timer
      }
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (!mounted) return;
    if (_currentIndex > 0) {
      if (_pageController.hasClients) {
        // Clear the "started" flag for the target index so imageBuilder can restart it
        _timersStartedIndices.remove(_currentIndex - 1);
        _pageController.previousPage(
          duration: const Duration(milliseconds: 1),
          curve: Curves.easeInOut,
        );
        // _onPageChanged will handle preparing the previous timer
      }
    } else {
      // At the first story, reset and restart its timer if needed
      _timersStartedIndices.remove(0); // Allow imageBuilder to trigger again
      _animationController?.reset();
      // Let imageBuilder trigger the forward() call again
      // _triggerTimerStart(0); // Or could force start here if image is likely cached
    }
  }

  // Pause/Resume remain the same
  void _pauseTimer() { _animationController?.stop(); }
  void _resumeTimer() {
    if (_animationController != null &&
        !_animationController!.isCompleted &&
        !_animationController!.isAnimating &&
        _animationController!.status != AnimationStatus.dismissed) {
      _animationController!.forward();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: buildBody(),
      ),
    );
  }

  // --- Helper method to build the main body content ---
  Widget buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_accentColor)));
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: _secondaryTextColor)));
    }

    if (_stories.isEmpty) {
      return const Center(child: Text("No stories available.", style: TextStyle(color: _secondaryTextColor)));
    }

    // --- Main Content Structure (GestureDetector wraps Stack) ---
    return GestureDetector(
      onTapUp: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < screenWidth / 4) {
          _previousStory();
        } else {
          _nextStory();
        }
      },
      onLongPressStart: (_) => _pauseTimer(),
      onLongPressEnd: (_) => _resumeTimer(),
      child: Stack(
        children: [
          // PageView for Stories
          PageView.builder(
            controller: _pageController,
            itemCount: _stories.length,
            onPageChanged: _onPageChanged,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final story = _stories[index];
              final contentUrl = story['content_url'];

              return Container(
                color: _backgroundColor,
                child: CachedNetworkImage(
                  key: ValueKey(contentUrl),
                  imageUrl: contentUrl,
                  fit: BoxFit.contain,
                  imageBuilder: (context, imageProvider) { // imageProvider is correctly named here by the callback
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && index == _currentIndex) {
                        _triggerTimerStart(index);
                      }
                    });
                    // **** FIX IS HERE: Pass imageProvider to the 'image' parameter ****
                    return Image(image: imageProvider, fit: BoxFit.contain);
                  },
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_placeholderColor))),
                  errorWidget: (context, url, error) => const Center(child: Icon(Icons.error_outline, color: Colors.redAccent, size: 50)),
                ),
              );
            },
          ), // --- End PageView ---

          // --- Overlays ---
          buildOverlays(),
        ],
      ),
    );
  }


  // --- buildOverlays method remains the same as previous version ---
  Widget buildOverlays() {
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress Bars Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: List.generate(_stories.length, (index) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: LinearPercentIndicator(
                      // Use a unique key based on index AND current page for updates
                      key: ValueKey('progress_${index}_$_currentIndex'),
                      lineHeight: 2.5,
                      percent: (_currentIndex == index)
                      // Use value directly; listener updates state
                          ? (_animationController?.value ?? 0.0)
                          : (_currentIndex > index ? 1.0 : 0.0),
                      backgroundColor: Colors.white.withOpacity(0.4),
                      progressColor: _primaryTextColor,
                      barRadius: const Radius.circular(2),
                      padding: EdgeInsets.zero,
                      // Animation related properties might not be needed if driven by controller value
                      // animateFromLastPercent: _currentIndex == index,
                      // animation: _currentIndex == index,
                    ),
                  ),
                );
              }),
            ),
          ),
          // User Info and Close Button Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[700],
                  backgroundImage: (_displayProfilePicUrl != null && _displayProfilePicUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(_displayProfilePicUrl!)
                      : null,
                  child: (_displayProfilePicUrl == null || _displayProfilePicUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 20, color: _secondaryTextColor)
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  _displayUsername ?? 'User',
                  style: const TextStyle(color: _primaryTextColor, fontWeight: FontWeight.bold, fontSize: 14, shadows: [Shadow(blurRadius: 2, color: Colors.black54)]),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: _primaryTextColor, shadows: [Shadow(blurRadius: 2, color: Colors.black54)]),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  } // --- End buildOverlays ---

} // End of _StoryViewPageState