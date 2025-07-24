import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AudioScreenStandalone extends StatefulWidget {
  final bool isAudioPlayerReady;
  final String Function(Duration) formatDuration;
  final String playbackState; // 'playing', 'paused', etc.
  final int playbackPositionMs;
  final int? totalDurationMs;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback? onMoreOptions;
  final VoidCallback onPlayPause;

  const AudioScreenStandalone({
    Key? key,
    required this.isAudioPlayerReady,
    required this.formatDuration,
    required this.playbackState,
    required this.playbackPositionMs,
    this.totalDurationMs,
    required this.onNext,
    required this.onPrevious,
    this.onMoreOptions,
    required this.onPlayPause,
  }) : super(key: key);

  @override
  State<AudioScreenStandalone> createState() => _AudioScreenStandaloneState();
}

class _AudioScreenStandaloneState extends State<AudioScreenStandalone>
    with SingleTickerProviderStateMixin {
  late int _lastNativePosition;
  late int _lastNativeUpdateTime;
  Ticker? _ticker;
  bool _isUserSeeking = false;
  int? _seekTarget;
  double _sliderValue = 0;
  Timer? _sleepTimer;
  int? _sleepMinutes;

  @override
  void initState() {
    super.initState();
    _sliderValue = widget.playbackPositionMs.toDouble();
    _lastNativePosition = widget.playbackPositionMs;
    _lastNativeUpdateTime = DateTime.now().millisecondsSinceEpoch;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(AudioScreenStandalone oldWidget) {
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
    _sleepTimer?.cancel();
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
                if (widget.onMoreOptions != null)
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: widget.onMoreOptions,
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.skip_previous, color: Colors.white),
                      iconSize: 48,
                      onPressed: widget.onPrevious,
                    ),
                    IconButton(
                      iconSize: 64,
                      color: Colors.white,
                      icon: Icon(
                        widget.playbackState == 'playing'
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      onPressed: widget.onPlayPause,
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_next, color: Colors.white),
                      iconSize: 48,
                      onPressed: widget.onNext,
                    ),
                  ],
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
                    // This should be handled by the parent via onMoreOptions or similar
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
