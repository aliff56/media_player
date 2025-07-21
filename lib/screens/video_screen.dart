import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:floating/floating.dart';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:media_store_plus/src/dir_type.dart';
import 'package:media_store_plus/media_store_platform_interface.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:just_audio/just_audio.dart';
import '../services/native_audio_service.dart';
import 'audio_screen.dart';

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

  // Playback speed state
  double _playbackSpeed = 1.0;
  final List<double> _speedOptions = [0.25, 0.5, 1.0, 1.5, 2.0];

  double? _seekBarValue; // For responsive seek bar
  bool _isSeeking = false;
  // For horizontal seek gesture
  double? _dragStartDx;
  Duration? _dragStartPosition;
  double _seekOffsetSeconds = 0;
  bool _showSeekOverlay = false;

  // Screenshot key
  final GlobalKey _videoScreenshotKey = GlobalKey();
  AudioPlayer? _audioPlayer;
  bool _isAudioOnly = false;
  bool _isAudioPlayerReady = false;

  // Aspect ratio modes
  final List<String> _aspectModes = [
    'Original',
    'Fit',
    'Crop',
    'Stretch',
    '16:9',
    '4:3',
  ];
  int _aspectModeIndex = 0;
  String? _aspectModeOverlayText;
  Timer? _aspectModeOverlayTimer;

  StreamSubscription<Map<String, dynamic>>? _audioStateSub;
  String _audioState = 'paused';
  int _audioPositionMs = 0;
  int? _audioTotalDurationMs;

  void _cycleAspectMode() {
    setState(() {
      _aspectModeIndex = (_aspectModeIndex + 1) % _aspectModes.length;
      _aspectModeOverlayText = _aspectModes[_aspectModeIndex];
    });
    _aspectModeOverlayTimer?.cancel();
    _aspectModeOverlayTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _aspectModeOverlayText = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initializeAndPlay(_currentIndex);
    _initBrightness();
    _startHideTimer();
    _audioPlayer = AudioPlayer();
    _audioStateSub = NativeAudioService.playbackStateStream.listen((event) {
      setState(() {
        _audioState = event['state'] ?? 'paused';
        _audioPositionMs = event['position'] ?? 0;
        _audioTotalDurationMs = event['duration'];
      });
    });
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
      // Set playback speed after initialization
      controller.setPlaybackSpeed(_playbackSpeed);
      _setInitialOrientation();
      controller.play();
    }
  }

  Future<void> _setInitialOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    setState(() {
      _isLandscape = false;
    });
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

  Future<void> _captureAndSaveScreenshot() async {
    try {
      RenderRepaintBoundary boundary =
          _videoScreenshotKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) throw Exception('Failed to get image bytes');
      Uint8List pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final fileName =
          'video_screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);
      await MediaStore.ensureInitialized();
      final saveInfo = await MediaStorePlatform.instance.saveFile(
        tempFilePath: file.path,
        fileName: fileName,
        dirType: DirType.photo,
        dirName: DirName.pictures,
        relativePath: '',
      );
      if (saveInfo != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Screenshot saved to gallery!')),
          );
        }
      } else {
        throw Exception('MediaStore.saveFile failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save screenshot: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _switchToAudio() async {
    if (_controller == null) return;
    final file = await widget.videoAssets[_currentIndex].file;
    if (file == null) return;
    final position = _controller!.value.position;
    await _controller!.pause();
    await NativeAudioService.startAudio(file.path, position.inMilliseconds);
    setState(() {
      _isAudioOnly = true;
      _isAudioPlayerReady = true;
    });
  }

  Future<void> _switchToVideo() async {
    // Stop native audio and get last position
    final positionMs = _audioPositionMs;
    await NativeAudioService.pauseAudio();
    setState(() {
      _isAudioOnly = false;
    });
    // Resume video from where audio stopped
    if (_controller != null) {
      await _controller!.seekTo(Duration(milliseconds: positionMs));
      await _controller!.play();
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return '${d.inHours > 0 ? '${twoDigits(d.inHours)}:' : ''}$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  void dispose() {
    _audioStateSub?.cancel();
    _hideTimer?.cancel();
    _controller?.pause();
    _controller?.dispose();
    _audioPlayer?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Widget _buildAspectRatioVideo() {
    final aspectRatio = _controller!.value.aspectRatio;
    final mode = _aspectModes[_aspectModeIndex];
    switch (mode) {
      case 'Crop':
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        );
      case 'Stretch':
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.fill,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        );
      case '16:9':
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: FittedBox(
            fit: BoxFit.fill,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        );
      case '4:3':
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: FittedBox(
            fit: BoxFit.fill,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        );
      case 'Fit':
        return AspectRatio(
          aspectRatio: aspectRatio,
          child: FittedBox(
            fit: BoxFit.contain,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        );
      case 'Original':
      default:
        return AspectRatio(
          aspectRatio: aspectRatio,
          child: FittedBox(
            fit: BoxFit.contain,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        );
    }
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
            onHorizontalDragStart:
                _isLocked ||
                    _controller == null ||
                    !_controller!.value.isInitialized ||
                    _isAudioOnly
                ? null
                : (details) {
                    _dragStartDx = details.localPosition.dx;
                    _dragStartPosition = _controller!.value.position;
                    _seekOffsetSeconds = 0;
                    setState(() {
                      _showSeekOverlay = true;
                    });
                  },
            onHorizontalDragUpdate:
                _isLocked ||
                    _controller == null ||
                    !_controller!.value.isInitialized ||
                    _isAudioOnly
                ? null
                : (details) {
                    if (_dragStartDx != null && _dragStartPosition != null) {
                      final dx = details.localPosition.dx - _dragStartDx!;
                      final screenWidth = constraints.maxWidth;
                      final seconds = dx / (screenWidth / 3) * 60;
                      setState(() {
                        _seekOffsetSeconds = seconds;
                        _showSeekOverlay = true;
                      });
                    }
                  },
            onHorizontalDragEnd:
                _isLocked ||
                    _controller == null ||
                    !_controller!.value.isInitialized ||
                    _isAudioOnly
                ? null
                : (details) {
                    if (_dragStartPosition != null) {
                      final newPosition =
                          _dragStartPosition! +
                          Duration(seconds: _seekOffsetSeconds.round());
                      final duration = _controller!.value.duration;
                      final clamped = newPosition < Duration.zero
                          ? Duration.zero
                          : (newPosition > duration ? duration : newPosition);
                      _controller!.seekTo(clamped);
                    }
                    setState(() {
                      _showSeekOverlay = false;
                      _seekOffsetSeconds = 0;
                      _dragStartDx = null;
                      _dragStartPosition = null;
                    });
                    _startHideTimer();
                  },
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                if (_isAudioOnly)
                  AudioScreen(
                    isAudioPlayerReady: _isAudioPlayerReady,
                    formatDuration: _formatDuration,
                    onSwitchToVideo: () async {
                      await _switchToVideo();
                    },
                    playbackState: _audioState,
                    playbackPositionMs: _audioPositionMs,
                    totalDurationMs: _audioTotalDurationMs,
                  ),
                if (!_isAudioOnly)
                  Center(
                    child:
                        _controller != null && _controller!.value.isInitialized
                        ? RepaintBoundary(
                            key: _videoScreenshotKey,
                            child: _buildAspectRatioVideo(),
                          )
                        : const CircularProgressIndicator(),
                  ),
                // Aspect ratio mode overlay
                if (_aspectModeOverlayText != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _aspectModeOverlayText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Overlays and controls (show only if not audio only)
                if (!_isAudioOnly) ...[
                  if (_showSeekOverlay &&
                      _controller != null &&
                      _controller!.value.isInitialized)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _seekOffsetSeconds > 0
                                  ? Icons.fast_forward
                                  : Icons.fast_rewind,
                              color: Colors.white,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                final duration = _controller!.value.duration;
                                final start =
                                    _dragStartPosition ?? Duration.zero;
                                final maxSeek = duration - start;
                                final minSeek = -start.inSeconds.toDouble();
                                final clampedOffset = _seekOffsetSeconds.clamp(
                                  minSeek,
                                  maxSeek.inSeconds.toDouble(),
                                );
                                return Text(
                                  (clampedOffset > 0 ? '+' : '') +
                                      clampedOffset.round().toString() +
                                      's',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
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
                  if (_showControls && !_isLocked) ...[
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: Container(
                        height: 75,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                        ),
                      ),
                    ),
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
                          PopupMenuButton<double>(
                            initialValue: _playbackSpeed,
                            tooltip: 'Playback Speed',
                            onSelected: (speed) {
                              setState(() {
                                _playbackSpeed = speed;
                              });
                              _controller?.setPlaybackSpeed(speed);
                            },
                            color: Colors.black87,
                            itemBuilder: (context) => _speedOptions
                                .map(
                                  (speed) => PopupMenuItem<double>(
                                    value: speed,
                                    child: Text(
                                      '${speed}x',
                                      style: TextStyle(
                                        color: speed == _playbackSpeed
                                            ? Colors.blue
                                            : Colors.white,
                                        fontWeight: speed == _playbackSpeed
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_playbackSpeed}x',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
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
                          IconButton(
                            icon: const Icon(
                              Icons.picture_in_picture_alt,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              final floating = Floating();
                              final rational = Rational.landscape();
                              final screenSize =
                                  MediaQuery.of(context).size *
                                  MediaQuery.of(context).devicePixelRatio;
                              final height =
                                  screenSize.width ~/ rational.aspectRatio;
                              final arguments = ImmediatePiP(
                                aspectRatio: rational,
                                sourceRectHint: Rectangle<int>(
                                  0,
                                  (screenSize.height ~/ 2) - (height ~/ 2),
                                  screenSize.width.toInt(),
                                  height,
                                ),
                              );
                              final status = await floating.enable(arguments);
                              debugPrint('PiP enabled? $status');
                            },
                            tooltip: 'Enable Picture-in-Picture',
                          ),
                          IconButton(
                            icon: Icon(
                              _isAudioOnly ? Icons.videocam : Icons.audiotrack,
                              color: Colors.white,
                            ),
                            tooltip: _isAudioOnly
                                ? 'Switch to Video'
                                : 'Audio Only',
                            onPressed: () async {
                              if (_isAudioOnly) {
                                await _switchToVideo();
                              } else {
                                await _switchToAudio();
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.aspect_ratio, color: Colors.white),
                            onPressed: _cycleAspectMode,
                            tooltip: 'Change Aspect Ratio',
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 32,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          if (_controller != null &&
                              _controller!.value.isInitialized)
                            Container(
                              height: 90,
                              margin: const EdgeInsets.symmetric(horizontal: 0),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                              ),
                            ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    iconSize: 32,
                                    color: Colors.white,
                                    icon: const Icon(Icons.camera_alt),
                                    tooltip: 'Take Screenshot',
                                    onPressed: _captureAndSaveScreenshot,
                                  ),
                                  IconButton(
                                    iconSize: 32,
                                    color: Colors.white,
                                    icon: Icon(
                                      _isMuted
                                          ? Icons.volume_off
                                          : Icons.volume_up,
                                    ),
                                    onPressed: () {
                                      _setMute(!_isMuted);
                                      _startHideTimer();
                                    },
                                  ),
                                  IconButton(
                                    iconSize: 36,
                                    color: _currentIndex > 0
                                        ? Colors.white
                                        : Colors.white24,
                                    icon: const Icon(Icons.skip_previous),
                                    onPressed: _currentIndex > 0
                                        ? _playPrevious
                                        : null,
                                  ),
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
                                            _controller!
                                                .value
                                                .duration
                                                .inSeconds,
                                          ),
                                        ),
                                      );
                                      _startHideTimer();
                                    },
                                  ),
                                  IconButton(
                                    iconSize: 48,
                                    color: Colors.white,
                                    icon: Icon(
                                      _controller != null &&
                                              _controller!.value.isPlaying
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
                                  IconButton(
                                    iconSize: 36,
                                    color: Colors.white,
                                    icon: const Icon(Icons.forward_10),
                                    onPressed: () {
                                      if (_controller == null) return;
                                      final pos = _controller!.value.position;
                                      final duration =
                                          _controller!.value.duration;
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
                                  IconButton(
                                    iconSize: 36,
                                    color:
                                        _currentIndex <
                                            widget.videoAssets.length - 1
                                        ? Colors.white
                                        : Colors.white24,
                                    icon: const Icon(Icons.skip_next),
                                    onPressed:
                                        _currentIndex <
                                            widget.videoAssets.length - 1
                                        ? _playNext
                                        : null,
                                  ),
                                ],
                              ),
                              if (_controller != null &&
                                  _controller!.value.isInitialized)
                                Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 12.0,
                                        right: 8.0,
                                      ),
                                      child: Text(
                                        _formatDuration(
                                          _isSeeking
                                              ? Duration(
                                                  milliseconds:
                                                      (_seekBarValue ?? 0)
                                                          .toInt(),
                                                )
                                              : _controller!.value.position,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 6.0,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 8.0,
                                              ),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                overlayRadius: 14.0,
                                              ),
                                          trackShape:
                                              const RoundedRectSliderTrackShape(),
                                          activeTrackColor: Colors.white,
                                          inactiveTrackColor: Colors.white38,
                                          thumbColor: Colors.white,
                                          overlayColor: Colors.white24,
                                        ),
                                        child: Slider(
                                          value: _isSeeking
                                              ? (_seekBarValue ?? 0)
                                              : _controller!
                                                    .value
                                                    .position
                                                    .inMilliseconds
                                                    .toDouble()
                                                    .clamp(
                                                      0,
                                                      _controller!
                                                          .value
                                                          .duration
                                                          .inMilliseconds
                                                          .toDouble(),
                                                    ),
                                          min: 0,
                                          max: _controller!
                                              .value
                                              .duration
                                              .inMilliseconds
                                              .toDouble(),
                                          onChanged: (value) {
                                            setState(() {
                                              _isSeeking = true;
                                              _seekBarValue = value;
                                            });
                                          },
                                          onChangeEnd: (value) {
                                            _controller!.seekTo(
                                              Duration(
                                                milliseconds: value.toInt(),
                                              ),
                                            );
                                            setState(() {
                                              _isSeeking = false;
                                              _seekBarValue = null;
                                            });
                                            _startHideTimer();
                                          },
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 12.0,
                                        left: 8.0,
                                      ),
                                      child: Text(
                                        _formatDuration(
                                          _controller!.value.duration,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
