// This will be the new main screen file.
// It will contain the VideoScreen StatefulWidget and _VideoScreenState.
// The build method will be simplified to use the new modular widgets.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:floating/floating.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cast/cast.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:media_store_plus/media_store_plus.dart' show MediaStorePlatform;

import 'widgets/video_controls_overlay.dart';
import 'widgets/player_gestures.dart';
import '../audio_screen.dart';
import '../../services/native_audio_service.dart';
import '../video_trim_screen.dart';

class VideoPlayerScreen extends StatefulWidget {
  final List<AssetEntity> videoAssets;
  final int initialIndex;

  const VideoPlayerScreen({
    Key? key,
    required this.videoAssets,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player player;
  late final VideoController controller;

  bool _isLandscape = false;
  bool _showControls = true;
  Timer? _hideTimer;
  late int _currentIndex;

  double _currentVolume = 0.5;
  bool _showVolumeOverlay = false;
  double? _dragStartDy;
  double? _dragStartVolume;

  double _currentBrightness = 0.5;
  bool _showBrightnessOverlay = false;
  double? _dragStartBrightness;

  bool _isMuted = false;
  bool _isLocked = false;

  double _playbackSpeed = 1.0;
  final List<double> _speedOptions = [0.25, 0.5, 1.0, 1.5, 2.0];

  double? _seekBarValue;
  bool _isSeeking = false;

  double? _dragStartDx;
  Duration? _dragStartPosition;
  double _seekOffsetSeconds = 0;
  bool _showSeekOverlay = false;

  final GlobalKey _videoScreenshotKey = GlobalKey();
  bool _isAudioOnly = false;
  bool _isAudioPlayerReady = false;

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

  // Cast devices cache
  List<CastDevice>? _castDevices;

  StreamSubscription<Map<String, dynamic>>? _audioStateSub;
  String _audioState = 'paused';
  int _audioPositionMs = 0;
  int? _audioTotalDurationMs;

  bool get isPlayerInitialized => player.state.playlist.medias.isNotEmpty;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    _currentIndex = widget.initialIndex;
    _initializeAndPlay(_currentIndex);
    _initBrightness();
    _startHideTimer();
    _audioStateSub = NativeAudioService.playbackStateStream.listen((event) {
      if (mounted) {
        setState(() {
          _audioState = event['state'] ?? 'paused';
          _audioPositionMs = event['position'] ?? 0;
          _audioTotalDurationMs = event['duration'];
        });
      }
    });
  }

  @override
  void dispose() {
    _audioStateSub?.cancel();
    _hideTimer?.cancel();
    player.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _cycleAspectMode() {
    setState(() {
      _aspectModeIndex = (_aspectModeIndex + 1) % _aspectModes.length;
      _aspectModeOverlayText = _aspectModes[_aspectModeIndex];
    });
    _aspectModeOverlayTimer?.cancel();
    _aspectModeOverlayTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _aspectModeOverlayText = null);
      }
    });
  }

  Future<void> _initBrightness() async {
    try {
      _currentBrightness = await ScreenBrightness.instance.application;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _setBrightness(double value) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(value);
      _currentBrightness = value;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _initializeAndPlay(int index, {bool pause = false}) async {
    final file = await widget.videoAssets[index].file;
    if (file != null) {
      await player.open(Media(file.path), play: !pause);
      player.setVolume(_currentVolume * 100);
      player.setRate(_playbackSpeed);
      _setInitialOrientation();
    }
  }

  Future<void> _setInitialOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (mounted) {
      setState(() {
        _isLandscape = false;
      });
    }
  }

  void _setLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (mounted) {
      setState(() {
        _isLandscape = true;
      });
    }
  }

  void _setPortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (mounted) {
      setState(() {
        _isLandscape = false;
      });
    }
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
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _onTapVideo() {
    if (mounted) {
      setState(() {
        _showControls = true;
      });
    }
    _startHideTimer();
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      if (mounted) {
        setState(() {
          _currentIndex--;
        });
      }
      if (_isAudioOnly) {
        _switchToAudio(resumePosition: Duration.zero);
        _initializeAndPlay(_currentIndex, pause: true);
      } else {
        _initializeAndPlay(_currentIndex);
        _startHideTimer();
      }
    }
  }

  void _playNext() {
    if (_currentIndex < widget.videoAssets.length - 1) {
      if (mounted) {
        setState(() {
          _currentIndex++;
        });
      }
      if (_isAudioOnly) {
        _switchToAudio(resumePosition: Duration.zero);
        _initializeAndPlay(_currentIndex, pause: true);
      } else {
        _initializeAndPlay(_currentIndex);
        _startHideTimer();
      }
    }
  }

  void _onVerticalDragStart(
    DragStartDetails details,
    BoxConstraints constraints,
  ) {
    final width = constraints.maxWidth;
    _dragStartDy = details.localPosition.dy;
    if (details.localPosition.dx <= width / 3) {
      _dragStartBrightness = _currentBrightness;
      if (mounted) setState(() => _showBrightnessOverlay = true);
    } else if (details.localPosition.dx >= width * 2 / 3) {
      _dragStartVolume = _currentVolume;
      if (mounted) setState(() => _showVolumeOverlay = true);
    }
  }

  void _onVerticalDragUpdate(
    DragUpdateDetails details,
    BoxConstraints constraints,
  ) {
    if (_dragStartDy == null) return;
    final delta =
        (_dragStartDy! - details.localPosition.dy) / constraints.maxHeight;
    if (_dragStartVolume != null) {
      _currentVolume = (_dragStartVolume! + delta).clamp(0.0, 1.0);
      player.setVolume(_currentVolume * 100);
    } else if (_dragStartBrightness != null) {
      _currentBrightness = (_dragStartBrightness! + delta).clamp(0.0, 1.0);
      _setBrightness(_currentBrightness);
    }
    if (mounted) setState(() {});
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (mounted) {
      setState(() {
        _showVolumeOverlay = false;
        _showBrightnessOverlay = false;
        _dragStartDy = null;
        _dragStartVolume = null;
        _dragStartBrightness = null;
      });
    }
  }

  Future<void> _setMute(bool mute) async {
    await player.setVolume(mute ? 0.0 : _currentVolume * 100);
    if (mounted) {
      setState(() {
        _isMuted = mute;
      });
    }
  }

  void _toggleLock() {
    if (mounted) {
      setState(() {
        _isLocked = !_isLocked;
      });
    }
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
      final mediaStore = MediaStore();
      final saveInfo = await mediaStore.saveFile(
        tempFilePath: file.path,
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

  Future<void> _switchToAudio({Duration? resumePosition}) async {
    final file = await widget.videoAssets[_currentIndex].file;
    if (file == null) return;
    final position = resumePosition ?? player.state.position;
    await player.pause();
    await NativeAudioService.startAudio(file.path, position.inMilliseconds);
    if (mounted) {
      setState(() {
        _isAudioOnly = true;
        _isAudioPlayerReady = true;
      });
    }
  }

  Future<void> _switchToVideo() async {
    final positionMs = _audioPositionMs;
    await NativeAudioService.pauseAudio();
    if (mounted) {
      setState(() {
        _isAudioOnly = false;
      });
    }
    await player.seek(Duration(milliseconds: positionMs));
    await player.play();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return d.inHours > 0
        ? '${twoDigits(d.inHours)}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Playback Speed
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Playback Speed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PopupMenuButton<double>(
                    initialValue: _playbackSpeed,
                    tooltip: 'Playback Speed',
                    onSelected: (speed) {
                      if (mounted) {
                        setState(() {
                          _playbackSpeed = speed;
                        });
                      }
                      player.setRate(speed);
                      Navigator.pop(context);
                    },
                    color: Colors.grey[800],
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
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    child: Text(
                      '${_playbackSpeed}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Audio Tracks
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Audio Tracks',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.audiotrack, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                      _showAudioTracksDialog(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Trim Video
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trim',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cut, color: Colors.white),
                    onPressed: () async {
                      // Close the bottom sheet first
                      Navigator.pop(context);
                      // Get file before leaving
                      final file = await widget.videoAssets[_currentIndex].file;
                      if (file == null) return;
                      if (!mounted) return;
                      // Pause playback so audio stops immediately
                      try {
                        await player.pause();
                      } catch (_) {}

                      // Replace the current VideoPlayerScreen with the trim screen
                      Navigator.of(this.context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => VideoTrimScreen(originalFile: file),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Google Cast
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Google Cast',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cast, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                      _showCastDialog(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Share
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Share',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                      _shareCurrentVideo();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareCurrentVideo() async {
    try {
      final file = await widget.videoAssets[_currentIndex].file;
      if (file == null) return;
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share video: ${e.toString()}')),
        );
      }
    }
  }

  void _showAudioTracksDialog(BuildContext context) {
    final List<AudioTrack> audioTracks = player.state.tracks.audio;
    final AudioTrack activeTrack = player.state.track.audio;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Audio Track'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: audioTracks.length,
            itemBuilder: (context, index) {
              final track = audioTracks[index];
              final title = track.title ?? track.id;
              final language = track.language;
              final displayText = language != null
                  ? '$title ($language)'
                  : title;
              return RadioListTile<AudioTrack>(
                title: Text(displayText),
                value: track,
                groupValue: activeTrack,
                onChanged: (selectedTrack) {
                  if (selectedTrack != null) {
                    player.setAudioTrack(selectedTrack);
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCastDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Cast Devices',
            style: TextStyle(color: Colors.white),
          ),
          content: FutureBuilder<List<CastDevice>>(
            future: _discoverCastDevices(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                );
              }
              final devices = snapshot.data ?? [];
              if (devices.isEmpty) {
                return const Text(
                  'No devices found',
                  style: TextStyle(color: Colors.white),
                );
              }
              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ListTile(
                      leading: const Icon(Icons.cast, color: Colors.white),
                      title: Text(
                        device.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _castToDevice(device);
                      },
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<List<CastDevice>> _discoverCastDevices() async {
    _castDevices ??= await CastDiscoveryService().search();
    return _castDevices!;
  }

  Future<void> _castToDevice(CastDevice device) async {
    try {
      final session = await CastSessionManager().startSession(device);
      final file = await widget.videoAssets[_currentIndex].file;
      if (file == null) return;
      // Note: Local files may not play on Chromecast. Provide warning.
      session.sendMessage(CastSession.kNamespaceReceiver, {
        'type': 'LAUNCH',
        'appId': 'CC1AD845', // Default media receiver
      });
      // After ready, load media (simple example using http sample if local)
      final mediaUrl = file.path; // Cast the currently playing video
      session.sendMessage(CastSession.kNamespaceMedia, {
        'type': 'LOAD',
        'autoPlay': true,
        'currentTime': 0,
        'media': {
          'contentId': mediaUrl,
          'contentType': 'video/mp4',
          'streamType': 'BUFFERED',
          'metadata': {
            'type': 0,
            'metadataType': 0,
            'title': file.uri.pathSegments.isNotEmpty
                ? file.uri.pathSegments.last
                : 'Video',
            'images': [],
          },
        },
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Casting to ${device.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cast: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildAspectRatioVideo() {
    final mode = _aspectModes[_aspectModeIndex];
    BoxFit fit;
    switch (mode) {
      case 'Crop':
        fit = BoxFit.cover;
        break;
      case 'Stretch':
        fit = BoxFit.fill;
        break;
      default:
        fit = BoxFit.contain;
        break;
    }
    double? aspectRatio;
    if (mode == '16:9') aspectRatio = 16 / 9;
    if (mode == '4:3') aspectRatio = 4 / 3;
    final video = Video(
      controller: controller,
      fit: fit,
      aspectRatio: aspectRatio,
      controls: NoVideoControls,
    );
    if (mode == 'Original' || mode == 'Fit') {
      return Center(child: video);
    }
    return video;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PlayerGestures(
        onTap: _onTapVideo,
        onHorizontalDragStart: (details) {
          if (_isLocked || !isPlayerInitialized || _isAudioOnly) return;
          _dragStartDx = details.localPosition.dx;
          _dragStartPosition = player.state.position;
          _seekOffsetSeconds = 0;
          if (mounted) setState(() => _showSeekOverlay = true);
        },
        onHorizontalDragUpdate: (details) {
          if (_isLocked ||
              !isPlayerInitialized ||
              _isAudioOnly ||
              _dragStartDx == null)
            return;
          final screenWidth = MediaQuery.of(context).size.width;
          final dx = details.localPosition.dx - _dragStartDx!;
          _seekOffsetSeconds = (dx / (screenWidth / 3) * 60);
          if (mounted) setState(() {});
        },
        onHorizontalDragEnd: (details) {
          if (_isLocked || !isPlayerInitialized || _isAudioOnly) return;
          if (_dragStartPosition != null) {
            final newPosition =
                _dragStartPosition! +
                Duration(seconds: _seekOffsetSeconds.round());
            player.seek(
              newPosition.clamp(Duration.zero, player.state.duration),
            );
          }
          if (mounted) {
            setState(() {
              _showSeekOverlay = false;
              _seekOffsetSeconds = 0;
              _dragStartDx = null;
              _dragStartPosition = null;
            });
          }
          _startHideTimer();
        },
        onVerticalDragStart: (details, constraints) =>
            _onVerticalDragStart(details, constraints),
        onVerticalDragUpdate: (details, constraints) =>
            _onVerticalDragUpdate(details, constraints),
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Stack(
          children: [
            if (_isAudioOnly)
              AudioScreen(
                isAudioPlayerReady: _isAudioPlayerReady,
                formatDuration: _formatDuration,
                onSwitchToVideo: _switchToVideo,
                playbackState: _audioState,
                playbackPositionMs: _audioPositionMs,
                totalDurationMs: _audioTotalDurationMs,
                onNext: _playNext,
                onPrevious: _playPrevious,
              )
            else
              Center(
                child: isPlayerInitialized
                    ? RepaintBoundary(
                        key: _videoScreenshotKey,
                        child: _buildAspectRatioVideo(),
                      )
                    : const CircularProgressIndicator(),
              ),
            if (!_isAudioOnly)
              VideoControlsOverlay(
                player: player,
                isPlayerInitialized: isPlayerInitialized,
                showControls: _showControls,
                isLocked: _isLocked,
                toggleLock: _toggleLock,
                onMoreOptions: () => _showMoreOptions(context),
                toggleOrientation: _toggleOrientation,
                isLandscape: _isLandscape,
                onEnablePiP: () async => await Floating().enable(
                  const ImmediatePiP(aspectRatio: Rational.landscape()),
                ),
                onSwitchToAudio: _switchToAudio,
                onCaptureScreenshot: _captureAndSaveScreenshot,
                onMute: () => _setMute(!_isMuted),
                isMuted: _isMuted,
                onPlayPrevious: _playPrevious,
                canPlayPrevious: _currentIndex > 0,
                onPlayNext: _playNext,
                canPlayNext: _currentIndex < widget.videoAssets.length - 1,
                seekOffsetSeconds: _seekOffsetSeconds,
                currentVolume: _currentVolume,
                currentBrightness: _currentBrightness,
                showSeekOverlay: _showSeekOverlay,
                showVolumeOverlay: _showVolumeOverlay,
                showBrightnessOverlay: _showBrightnessOverlay,
                formatDuration: _formatDuration,
                cycleAspectMode: _cycleAspectMode,
                startHideTimer: _startHideTimer,
                aspectModeOverlayText: _aspectModeOverlayText,
              ),
          ],
        ),
      ),
    );
  }
}

extension DurationClamp on Duration {
  Duration clamp(Duration min, Duration max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }
}
