import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';

class VideoScreen extends StatefulWidget {
  final List<AssetEntity> videoAssets;
  final int initialIndex;
  const VideoScreen({
    Key? key,
    required this.videoAssets,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  bool _isLandscape = true;
  bool _showControls = true;
  Timer? _hideTimer;
  late int _currentIndex;
  VideoPlayerController? _controller;

  // Volume control state
  double _currentVolume = 0.5;
  bool _showVolumeOverlay = false;
  double? _dragStartDy;
  double? _dragStartVolume;

  // Brightness control state
  double _currentBrightness = 0.5;
  bool _showBrightnessOverlay = false;
  double? _dragStartBrightness;

  bool _isMuted = false;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initializeAndPlay(_currentIndex);
    _initBrightness();
    _startHideTimer();
  }

  Future<void> _initBrightness() async {
    try {
      final brightness = await ScreenBrightness.instance.application;
      setState(() {
        _currentBrightness = brightness;
      });
    } catch (_) {}
  }

  Future<void> _setBrightness(double value) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(value);
      setState(() {
        _currentBrightness = value;
      });
    } catch (_) {}
  }

  Future<void> _initializeAndPlay(int index) async {
    _controller?.pause();
    _controller?.dispose();
    final file = await widget.videoAssets[index].file;
    if (file != null) {
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      setState(() {
        _controller = controller;
        _currentVolume = 0.5;
      });
      controller.setVolume(_currentVolume);
      _setInitialOrientation();
      controller.play();
    }
  }

  Future<void> _setInitialOrientation() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final aspectRatio = _controller!.value.aspectRatio;
    if (aspectRatio < 1.0) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      setState(() {
        _isLandscape = false;
      });
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      setState(() {
        _isLandscape = true;
      });
    }
  }

  void _setLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    setState(() {
      _isLandscape = true;
    });
  }

  void _setPortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    setState(() {
      _isLandscape = false;
    });
  }

  void _toggleOrientation() {
    if (_isLandscape) {
      _setPortrait();
    } else {
      _setLandscape();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (!_isLocked) {
      _hideTimer = Timer(const Duration(seconds: 2), () {
        setState(() {
          _showControls = false;
        });
      });
    }
  }

  void _onTapVideo() {
    setState(() {
      _showControls = true;
    });
    _startHideTimer();
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _initializeAndPlay(_currentIndex);
      _startHideTimer();
    }
  }

  void _playNext() {
    if (_currentIndex < widget.videoAssets.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _initializeAndPlay(_currentIndex);
      _startHideTimer();
    }
  }

  void _onVerticalDragStart(
    DragStartDetails details,
    BoxConstraints constraints,
  ) {
    final width = constraints.maxWidth;
    // Reset all drag states
    _dragStartDy = null;
    _dragStartVolume = null;
    _dragStartBrightness = null;
    setState(() {
      _showVolumeOverlay = false;
      _showBrightnessOverlay = false;
    });
    if (details.localPosition.dx <= width / 3) {
      // Left third of the screen: brightness
      _dragStartDy = details.localPosition.dy;
      _dragStartBrightness = _currentBrightness;
      setState(() {
        _showBrightnessOverlay = true;
      });
    } else if (details.localPosition.dx >= width * 2 / 3) {
      // Right third of the screen: volume
      _dragStartDy = details.localPosition.dy;
      _dragStartVolume = _currentVolume;
      setState(() {
        _showVolumeOverlay = true;
      });
    }
    // Middle third: do nothing
  }

  void _onVerticalDragUpdate(
    DragUpdateDetails details,
    BoxConstraints constraints,
  ) {
    if (_dragStartDy == null) return;
    final height = constraints.maxHeight;
    final delta = _dragStartDy! - details.localPosition.dy; // up is positive
    double change = delta / height; // drag full height = 1.0 change
    if (_dragStartVolume != null) {
      double newVolume = (_dragStartVolume! + change).clamp(0.0, 1.0);
      setState(() {
        _currentVolume = newVolume;
        _showVolumeOverlay = true;
      });
      _controller?.setVolume(_currentVolume);
    } else if (_dragStartBrightness != null) {
      double newBrightness = (_dragStartBrightness! + change).clamp(0.0, 1.0);
      setState(() {
        _currentBrightness = newBrightness;
        _showBrightnessOverlay = true;
      });
      _setBrightness(_currentBrightness);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _showVolumeOverlay = false;
      _showBrightnessOverlay = false;
    });
  }

  Future<void> _setMute(bool mute) async {
    setState(() {
      _isMuted = mute;
    });
    if (_controller != null) {
      await _controller!.setVolume(mute ? 0.0 : _currentVolume);
    }
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
    });
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.pause();
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTap: _isLocked ? null : _onTapVideo,
            onVerticalDragStart: _isLocked
                ? null
                : (details) => _onVerticalDragStart(details, constraints),
            onVerticalDragUpdate: _isLocked
                ? null
                : (details) => _onVerticalDragUpdate(details, constraints),
            onVerticalDragEnd: _isLocked ? null : _onVerticalDragEnd,
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                Center(
                  child: _controller != null && _controller!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        )
                      : const CircularProgressIndicator(),
                ),
                // Volume overlay
                if (_showVolumeOverlay)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.volume_up,
                            color: Colors.white,
                            size: 32,
                          ),
                          Text(
                            '${(_currentVolume * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Brightness overlay
                if (_showBrightnessOverlay)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.brightness_6,
                            color: Colors.white,
                            size: 32,
                          ),
                          Text(
                            '${(_currentBrightness * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Only show one lock button at a time
                if (_isLocked)
                  Positioned(
                    top: 32,
                    right: 16,
                    child: IconButton(
                      icon: Icon(Icons.lock, color: Colors.white),
                      onPressed: _toggleLock,
                      tooltip: 'Unlock Controls',
                    ),
                  ),
                // Show all other controls only if not locked
                if (_showControls && !_isLocked) ...[
                  Positioned(
                    top: 32,
                    left: 16,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    top: 32,
                    right: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Lock/Unlock button
                        IconButton(
                          icon: Icon(
                            _isLocked ? Icons.lock : Icons.lock_open,
                            color: Colors.white,
                          ),
                          onPressed: _toggleLock,
                          tooltip: _isLocked
                              ? 'Unlock Controls'
                              : 'Lock Controls',
                        ),
                        // Orientation button
                        IconButton(
                          icon: Icon(
                            _isLandscape
                                ? Icons.screen_lock_portrait
                                : Icons.screen_lock_landscape,
                            color: Colors.white,
                          ),
                          onPressed: _toggleOrientation,
                          tooltip: 'Toggle Orientation',
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mute/Unmute
                        IconButton(
                          iconSize: 32,
                          color: Colors.white,
                          icon: Icon(
                            _isMuted ? Icons.volume_off : Icons.volume_up,
                          ),
                          onPressed: () {
                            _setMute(!_isMuted);
                            _startHideTimer();
                          },
                        ),
                        // Previous video
                        IconButton(
                          iconSize: 36,
                          color: _currentIndex > 0
                              ? Colors.white
                              : Colors.white24,
                          icon: const Icon(Icons.skip_previous),
                          onPressed: _currentIndex > 0 ? _playPrevious : null,
                        ),
                        // Skip backward 10s
                        IconButton(
                          iconSize: 36,
                          color: Colors.white,
                          icon: const Icon(Icons.replay_10),
                          onPressed: () {
                            if (_controller == null) return;
                            final pos = _controller!.value.position;
                            _controller!.seekTo(
                              Duration(
                                seconds: (pos.inSeconds - 10).clamp(
                                  0,
                                  _controller!.value.duration.inSeconds,
                                ),
                              ),
                            );
                            _startHideTimer();
                          },
                        ),
                        // Play/Pause
                        IconButton(
                          iconSize: 48,
                          color: Colors.white,
                          icon: Icon(
                            _controller != null && _controller!.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                          ),
                          onPressed: () {
                            if (_controller == null) return;
                            setState(() {
                              if (_controller!.value.isPlaying) {
                                _controller!.pause();
                              } else {
                                _controller!.play();
                              }
                            });
                            _startHideTimer();
                          },
                        ),
                        // Skip forward 10s
                        IconButton(
                          iconSize: 36,
                          color: Colors.white,
                          icon: const Icon(Icons.forward_10),
                          onPressed: () {
                            if (_controller == null) return;
                            final pos = _controller!.value.position;
                            final duration = _controller!.value.duration;
                            _controller!.seekTo(
                              Duration(
                                seconds: (pos.inSeconds + 10).clamp(
                                  0,
                                  duration.inSeconds,
                                ),
                              ),
                            );
                            _startHideTimer();
                          },
                        ),
                        // Next video
                        IconButton(
                          iconSize: 36,
                          color: _currentIndex < widget.videoAssets.length - 1
                              ? Colors.white
                              : Colors.white24,
                          icon: const Icon(Icons.skip_next),
                          onPressed:
                              _currentIndex < widget.videoAssets.length - 1
                              ? _playNext
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
