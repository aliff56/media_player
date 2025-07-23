import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/native_audio_service.dart';
import 'audio_screen.dart';

class AudioPlayerScreen extends StatefulWidget {
  final List<AssetEntity> audios;
  final int initialIndex;
  const AudioPlayerScreen({
    Key? key,
    required this.audios,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late int _currentIndex;
  bool _isAudioPlayerReady = false;
  String _playbackState = 'paused';
  int _positionMs = 0;
  int? _durationMs;
  late final Stream<Map<String, dynamic>> _stateStream;
  late final StreamSubscription _sub;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _stateStream = NativeAudioService.playbackStateStream;
    _sub = _stateStream.listen((event) async {
      if (!mounted) return;
      // Handle native next/previous actions
      if (event.containsKey('action')) {
        if (event['action'] == 'next') {
          _playNext();
        } else if (event['action'] == 'previous') {
          _playPrevious();
        }
        return;
      }
      // Auto-play next track on completion
      if (event['state'] == 'completed') {
        if (_currentIndex < widget.audios.length - 1) {
          _currentIndex++;
          final file = await widget.audios[_currentIndex].file;
          if (file != null) {
            await NativeAudioService.playNextAudio(file.path, 0);
            setState(() {
              _isAudioPlayerReady = true;
            });
            _playbackSpeed = await NativeAudioService.getPlaybackSpeed();
          }
        }
        return;
      }
      setState(() {
        _playbackState = event['state'] ?? 'paused';
        _positionMs = event['position'] ?? 0;
        _durationMs = event['duration'];
      });
    });
    _startCurrent();
  }

  Future<void> _startCurrent() async {
    final file = await widget.audios[_currentIndex].file;
    if (file != null) {
      await NativeAudioService.startAudio(file.path, 0);
      setState(() {
        _isAudioPlayerReady = true;
      });
      _playbackSpeed = await NativeAudioService.getPlaybackSpeed();
    }
  }

  Future<void> _playNext() async {
    if (_currentIndex < widget.audios.length - 1) {
      _currentIndex++;
      await _startCurrent();
    }
  }

  Future<void> _playPrevious() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _startCurrent();
    }
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      builder: (c) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('Playback speed'),
                subtitle: Text('${_playbackSpeed}x'),
                onTap: () {
                  Navigator.pop(c);
                  _showSpeedSelect();
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Set as ringtone'),
                onTap: () async {
                  Navigator.pop(c);
                  final file = await widget.audios[_currentIndex].file;
                  if (file != null) {
                    final success = await NativeAudioService.setAsRingtone(
                      file.path,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success ? 'Ringtone set' : 'Failed to set ringtone',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSpeedSelect() {
    showModalBottomSheet(
      context: context,
      builder: (c) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var s in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                ListTile(
                  title: Text('${s}x'),
                  onTap: () async {
                    await NativeAudioService.setPlaybackSpeed(s);
                    setState(() {
                      _playbackSpeed = s;
                    });
                    Navigator.pop(c);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    return d.inHours > 0
        ? '${two(d.inHours)}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.audios[_currentIndex].title ?? 'Audio'),
      ),
      body: Container(
        color: Colors.black,
        child: AudioScreen(
          isAudioPlayerReady: _isAudioPlayerReady,
          formatDuration: _formatDuration,
          onSwitchToVideo: () {}, // not applicable
          playbackState: _playbackState,
          playbackPositionMs: _positionMs,
          totalDurationMs: _durationMs,
          onNext: _playNext,
          onPrevious: _playPrevious,
          onMoreOptions: _showOptions,
        ),
      ),
    );
  }
}
