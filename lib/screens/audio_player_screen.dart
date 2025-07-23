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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _stateStream = NativeAudioService.playbackStateStream;
    _sub = _stateStream.listen((event) {
      if (!mounted) return;
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
      setState(() => _isAudioPlayerReady = true);
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
        ),
      ),
    );
  }
}
