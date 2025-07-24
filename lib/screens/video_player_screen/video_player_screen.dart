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
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';

import 'widgets/video_controls_overlay.dart';
import 'widgets/player_gestures.dart';
import '../audio_screen.dart';
import '../../services/native_audio_service.dart';
import '../video_trim_screen.dart';
import 'widgets/bottom_controls.dart';

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

  StreamSubscription? _completedSub;
  StreamSubscription<Duration>? _positionSub;

  bool get isPlayerInitialized => player.state.playlist.medias.isNotEmpty;

  bool _vrMode = false;
  bool _mirrorMode = false;
  bool _isFavourite = false;
  List<int> _bookmarks = [];
  String _loopMode = 'order'; // 'order', 'loop', 'shuffle', 'stop'
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    _currentIndex = widget.initialIndex;
    _initPrefs();
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
    _completedSub = player.stream.completed.listen((completed) {
      if (completed == true) {
        _handlePlaybackModeOnComplete();
      }
    });
    _positionSub = player.stream.position.listen((pos) {
      final duration = player.state.duration;
      if (duration.inMilliseconds > 0 &&
          (pos.inMilliseconds >= duration.inMilliseconds - 500) &&
          !_isSeeking) {
        _handlePlaybackModeOnComplete();
      }
    });
  }

  @override
  void dispose() {
    _audioStateSub?.cancel();
    _hideTimer?.cancel();
    _aspectModeOverlayTimer?.cancel();
    player.dispose();
    _completedSub?.cancel();
    _positionSub?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFavourites();
    _loadBookmarks();
    _loadLoopMode();
  }

  void _loadFavourites() {
    final file = widget.videoAssets[_currentIndex].id;
    final favs = _prefs.getStringList('favourites') ?? [];
    setState(() {
      _isFavourite = favs.contains(file);
    });
  }

  void _toggleFavourite() {
    final file = widget.videoAssets[_currentIndex].id;
    final favs = _prefs.getStringList('favourites') ?? [];
    if (_isFavourite) {
      favs.remove(file);
    } else {
      favs.add(file);
    }
    _prefs.setStringList('favourites', favs);
    setState(() {
      _isFavourite = !_isFavourite;
    });
  }

  void _loadBookmarks() {
    final file = widget.videoAssets[_currentIndex].id;
    final marks = _prefs.getStringList('bookmarks_$file') ?? [];
    setState(() {
      _bookmarks = marks.map((e) => int.tryParse(e) ?? 0).toList();
    });
  }

  void _addBookmark() {
    final file = widget.videoAssets[_currentIndex].id;
    final pos = player.state.position.inMilliseconds;
    if (!_bookmarks.contains(pos)) {
      _bookmarks.add(pos);
      _prefs.setStringList(
        'bookmarks_$file',
        _bookmarks.map((e) => e.toString()).toList(),
      );
      setState(() {});
    }
  }

  void _removeBookmark(int pos) {
    final file = widget.videoAssets[_currentIndex].id;
    _bookmarks.remove(pos);
    _prefs.setStringList(
      'bookmarks_$file',
      _bookmarks.map((e) => e.toString()).toList(),
    );
    setState(() {});
  }

  void _loadLoopMode() {
    _loopMode = _prefs.getString('loop_mode') ?? 'order';
    setState(() {});
  }

  void _setLoopMode(String mode) {
    _loopMode = mode;
    _prefs.setString('loop_mode', mode);
    setState(() {});
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
      _loadFavourites();
      _loadBookmarks();
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
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Options'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _vrMode = !_vrMode);
              Navigator.pop(context);
            },
            child: Row(
              children: [
                Icon(Icons.vrpano, color: _vrMode ? Colors.blue : Colors.grey),
                const SizedBox(width: 12),
                Text(_vrMode ? 'Disable VR Mode' : 'Enable VR Mode'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _mirrorMode = !_mirrorMode);
              Navigator.pop(context);
            },
            child: Row(
              children: [
                Icon(
                  Icons.flip,
                  color: _mirrorMode ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 12),
                Text(
                  _mirrorMode ? 'Disable Mirror Mode' : 'Enable Mirror Mode',
                ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _addBookmark();
              Navigator.pop(context);
            },
            child: Row(
              children: const [
                Icon(Icons.bookmark_add, color: Colors.deepPurple),
                SizedBox(width: 12),
                Text('Add Bookmark'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _toggleFavourite();
              Navigator.pop(context);
            },
            child: Row(
              children: [
                Icon(
                  _isFavourite ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                const SizedBox(width: 12),
                Text(_isFavourite ? 'Remove Favourite' : 'Add Favourite'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              showCupertinoModalPopup(
                context: context,
                builder: (context) => CupertinoActionSheet(
                  title: const Text('Playback Mode'),
                  actions: [
                    CupertinoActionSheetAction(
                      onPressed: () {
                        _setLoopMode('order');
                        Navigator.pop(context);
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.queue_play_next,
                            color: _loopMode == 'order'
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          const Text('Play in Order'),
                        ],
                      ),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () {
                        _setLoopMode('loop');
                        Navigator.pop(context);
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.repeat_one,
                            color: _loopMode == 'loop'
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          const Text('Loop Current'),
                        ],
                      ),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () {
                        _setLoopMode('shuffle');
                        Navigator.pop(context);
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.shuffle,
                            color: _loopMode == 'shuffle'
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          const Text('Shuffle'),
                        ],
                      ),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () {
                        _setLoopMode('stop');
                        Navigator.pop(context);
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.stop,
                            color: _loopMode == 'stop'
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          const Text('Stop After Current'),
                        ],
                      ),
                    ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              );
            },
            child: Row(
              children: const [
                Icon(Icons.repeat, color: Colors.deepPurple),
                SizedBox(width: 12),
                Text('Playback Mode'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              final speed = await showCupertinoModalPopup<double>(
                context: context,
                builder: (context) => CupertinoActionSheet(
                  title: const Text('Playback Speed'),
                  actions: _speedOptions
                      .map(
                        (s) => CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(context, s),
                          child: Text(
                            '${s}x',
                            style: TextStyle(
                              color: s == _playbackSpeed
                                  ? Colors.blue
                                  : Colors.black,
                              fontWeight: s == _playbackSpeed
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              );
              if (speed != null) {
                setState(() {
                  _playbackSpeed = speed;
                });
                player.setRate(speed);
              }
            },
            child: Row(
              children: [
                Icon(Icons.speed, color: Colors.deepPurple),
                const SizedBox(width: 12),
                Text('Playback Speed: ${_playbackSpeed}x'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final file = await widget.videoAssets[_currentIndex].file;
              if (file == null) return;
              if (!mounted) return;
              try {
                await player.pause();
              } catch (_) {}
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VideoTrimScreen(originalFile: file),
                ),
              );
            },
            child: Row(
              children: const [
                Icon(Icons.cut, color: Colors.red),
                SizedBox(width: 12),
                Text('Trim Video'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
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
                        child: _vrMode
                            ? Row(
                                children: [
                                  Expanded(child: _buildTransformedVideo()),
                                  Expanded(child: _buildTransformedVideo()),
                                ],
                              )
                            : _buildTransformedVideo(),
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
                bookmarks: _bookmarks,
                onBookmarkTap: (ms) => player.seek(Duration(milliseconds: ms)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransformedVideo() {
    Widget video = _buildAspectRatioVideo();
    if (_mirrorMode) {
      video = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: video,
      );
    }
    return video;
  }

  void _handlePlaybackModeOnComplete() {
    if (_loopMode == 'order') {
      if (_currentIndex < widget.videoAssets.length - 1) {
        setState(() {
          _currentIndex++;
        });
        _initializeAndPlay(_currentIndex);
      }
      // else: do nothing (end of playlist)
    } else if (_loopMode == 'loop') {
      _initializeAndPlay(_currentIndex);
    } else if (_loopMode == 'shuffle') {
      final random = math.Random();
      int nextIndex = _currentIndex;
      if (widget.videoAssets.length > 1) {
        while (nextIndex == _currentIndex) {
          nextIndex = random.nextInt(widget.videoAssets.length);
        }
      }
      setState(() {
        _currentIndex = nextIndex;
      });
      _initializeAndPlay(_currentIndex);
    } else if (_loopMode == 'stop') {
      // Do nothing, stop playback
    }
  }
}

extension DurationClamp on Duration {
  Duration clamp(Duration min, Duration max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }
}
