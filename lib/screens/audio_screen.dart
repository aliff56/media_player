import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart';
import '../services/native_audio_service.dart';

class AudioScreen extends StatefulWidget {
  final bool isAudioPlayerReady;
  final String Function(Duration) formatDuration;
  final VoidCallback onSwitchToVideo;
  final String playbackState; // 'playing', 'paused', etc.
  final int playbackPositionMs;
  final int? totalDurationMs;

  const AudioScreen({
    Key? key,
    required this.isAudioPlayerReady,
    required this.formatDuration,
    required this.onSwitchToVideo,
    required this.playbackState,
    required this.playbackPositionMs,
    this.totalDurationMs,
  }) : super(key: key);

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen>
    with SingleTickerProviderStateMixin {
  late double _sliderValue;
  late int _lastNativePosition;
  late int _lastNativeUpdateTime;
  Ticker? _ticker;
  bool _isUserSeeking = false;
  int? _seekTarget;

  @override
  void initState() {
    super.initState();
    _sliderValue = widget.playbackPositionMs.toDouble();
    _lastNativePosition = widget.playbackPositionMs;
    _lastNativeUpdateTime = DateTime.now().millisecondsSinceEpoch;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(AudioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isUserSeeking && widget.playbackPositionMs != _lastNativePosition) {
      _sliderValue = widget.playbackPositionMs.toDouble();
      _lastNativePosition = widget.playbackPositionMs;
      _lastNativeUpdateTime = DateTime.now().millisecondsSinceEpoch;
    }
  }

  void _onTick(Duration elapsed) {
    if (!_isUserSeeking && widget.playbackState == 'playing') {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedMs = now - _lastNativeUpdateTime;
      final estPosition = _lastNativePosition + elapsedMs;
      final maxValue =
          (widget.totalDurationMs != null && widget.totalDurationMs! > 0)
          ? widget.totalDurationMs!.toDouble()
          : (_sliderValue + 1000);
      setState(() {
        _sliderValue = estPosition.clamp(0, maxValue).toDouble();
      });
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxValue =
        (widget.totalDurationMs != null && widget.totalDurationMs! > 0)
        ? widget.totalDurationMs!.toDouble()
        : (_sliderValue + 1000);
    return Center(
      child: widget.isAudioPlayerReady
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.audiotrack, color: Colors.white, size: 80),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: widget.onSwitchToVideo,
                  icon: Icon(Icons.videocam, color: Colors.white),
                  label: Text(
                    'Switch to Video',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 16),
                IconButton(
                  iconSize: 64,
                  color: Colors.white,
                  icon: Icon(
                    widget.playbackState == 'playing'
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: () async {
                    if (widget.playbackState == 'playing') {
                      (context as Element).markNeedsBuild();
                      await NativeAudioService.pauseAudio();
                    } else {
                      (context as Element).markNeedsBuild();
                      await NativeAudioService.playAudio();
                    }
                  },
                ),
                Slider(
                  value: _sliderValue.clamp(0, maxValue),
                  min: 0,
                  max: maxValue,
                  onChanged: (value) {
                    setState(() {
                      _isUserSeeking = true;
                      _sliderValue = value;
                      _seekTarget = value.toInt();
                    });
                  },
                  onChangeEnd: (value) async {
                    setState(() {
                      _isUserSeeking = false;
                    });
                    await NativeAudioService.seekTo(value.toInt());
                  },
                ),
                Text(
                  '${widget.formatDuration(Duration(milliseconds: _sliderValue.toInt()))} / '
                  '${widget.formatDuration(Duration(milliseconds: widget.totalDurationMs ?? 0))}',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            )
          : const CircularProgressIndicator(),
    );
  }
}
