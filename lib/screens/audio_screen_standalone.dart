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
  final void Function(int ms)? onSeek;
  final ImageProvider? albumArt;
  final String? lyrics;

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
    this.onSeek,
    this.albumArt,
    this.lyrics,
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
    final isPlaying = widget.playbackState == 'playing';
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF06141B),
            Color(0xFF11212D),
            Color(0xFF253745),
            Color(0xFF4A5C6A),
            Color(0xFF9BA8AB),
          ],
          stops: [0.0, 0.2, 0.45, 0.75, 1.0],
        ),
      ),
      child: Center(
        child: widget.isAudioPlayerReady
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Album art or icon with animated glow
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isPlaying
                              ? const Color(0xFF4A5C6A).withOpacity(0.45)
                              : const Color(0xFF253745).withOpacity(0.18),
                          blurRadius: isPlaying ? 32 : 12,
                          spreadRadius: isPlaying ? 8 : 2,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 3,
                      ),
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF9BA8AB),
                          Color(0xFF4A5C6A),
                          Color(0xFF06141B),
                        ],
                        radius: 0.9,
                      ),
                    ),
                    child: widget.albumArt != null
                        ? ClipOval(
                            child: Image(
                              image: widget.albumArt!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.audiotrack,
                            color: Colors.white.withOpacity(0.92),
                            size: 80,
                          ),
                  ),
                  const SizedBox(height: 24),
                  // Glassmorphism card for controls
                  Container(
                    width: 340,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      color: Colors.white.withOpacity(0.08),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.10),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title and options
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Now Playing',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.92),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            if (widget.onMoreOptions != null)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: widget.onMoreOptions,
                                  child: const Padding(
                                    padding: EdgeInsets.all(6.0),
                                    child: Icon(
                                      Icons.more_vert,
                                      color: Color(0xFF9BA8AB),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // Main controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _GlassIconButton(
                              icon: Icons.skip_previous,
                              onTap: widget.onPrevious,
                              size: 38,
                            ),
                            const SizedBox(width: 18),
                            _GlowingPlayPauseButton(
                              isPlaying: isPlaying,
                              onTap: widget.onPlayPause,
                            ),
                            const SizedBox(width: 18),
                            _GlassIconButton(
                              icon: Icons.skip_next,
                              onTap: widget.onNext,
                              size: 38,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // Progress bar with glow
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: 260,
                              height: 28,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: isPlaying
                                        ? const Color(
                                            0xFF4A5C6A,
                                          ).withOpacity(0.32)
                                        : const Color(
                                            0xFF253745,
                                          ).withOpacity(0.10),
                                    blurRadius: isPlaying ? 18 : 8,
                                    spreadRadius: isPlaying ? 2 : 0,
                                  ),
                                ],
                              ),
                            ),
                            _GlassProgressBar(
                              value: _sliderValue.clamp(0, maxValue),
                              max: maxValue,
                              onChanged: (value) {
                                setState(() {
                                  _isUserSeeking = true;
                                  _sliderValue = value;
                                  _seekTarget = value.toInt();
                                });
                              },
                              onChangeEnd: (value) {
                                setState(() {
                                  _isUserSeeking = false;
                                });
                                if (widget.onSeek != null) {
                                  widget.onSeek!(value.toInt());
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Time/duration pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.13),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${widget.formatDuration(Duration(milliseconds: _sliderValue.toInt()))} / '
                            '${widget.formatDuration(Duration(milliseconds: widget.totalDurationMs ?? 0))}',
                            style: const TextStyle(
                              color: Color(0xFFCCD0CF),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        // Animated waveform
                        const SizedBox(height: 16),
                        _AnimatedWaveform(),
                        // Lyrics area
                        const SizedBox(height: 16),
                        if (widget.lyrics != null && widget.lyrics!.isNotEmpty)
                          Container(
                            width: 320,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.lyrics!,
                              style: const TextStyle(
                                color: Color(0xFFCCD0CF),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (widget.lyrics == null || widget.lyrics!.isEmpty)
                          Container(
                            width: 220,
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white.withOpacity(0.07),
                            ),
                            child: Center(
                              child: Text(
                                'No lyrics available',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.32),
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

// Glassy icon button
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.size = 32,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: size + 16,
          height: size + 16,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF9BA8AB), size: size),
        ),
      ),
    );
  }
}

// Glowing play/pause button
class _GlowingPlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  const _GlowingPlayPauseButton({required this.isPlaying, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPlaying ? const Color(0xFF4A5C6A) : const Color(0xFF9BA8AB),
          boxShadow: [
            BoxShadow(
              color: isPlaying
                  ? const Color(0xFF4A5C6A).withOpacity(0.45)
                  : const Color(0xFF9BA8AB).withOpacity(0.22),
              blurRadius: isPlaying ? 24 : 10,
              spreadRadius: isPlaying ? 4 : 1,
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}

// Glassy progress bar
class _GlassProgressBar extends StatelessWidget {
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  const _GlassProgressBar({
    required this.value,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
  });
  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        activeTrackColor: const Color(0xFF4A5C6A),
        inactiveTrackColor: Colors.white.withOpacity(0.18),
        thumbColor: const Color(0xFFCCD0CF),
        overlayColor: const Color(0xFF4A5C6A).withOpacity(0.18),
      ),
      child: Slider(
        value: value,
        min: 0,
        max: max,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

// Animated waveform widget
class _AnimatedWaveform extends StatefulWidget {
  const _AnimatedWaveform();
  @override
  State<_AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<_AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 32,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return CustomPaint(painter: _WaveformPainter(t));
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double t;
  _WaveformPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A5C6A).withOpacity(0.7)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final midY = size.height / 2;
    for (int i = 0; i < 12; i++) {
      final x = i * size.width / 11;
      final phase = t * 2 * 3.14159 + i;
      final y =
          midY +
          (midY - 4) *
              (0.5 +
                  0.5 *
                      (0.7 * (i % 2 == 0 ? 1 : -1)) *
                      (0.7 + 0.3 * t) *
                      (0.5 + 0.5 * (i % 3 == 0 ? 1 : -1)) *
                      (0.7 + 0.3 * t) *
                      (0.5 + 0.5 * (i % 4 == 0 ? 1 : -1)) *
                      (0.7 + 0.3 * t) *
                      (0.5 + 0.5 * (i % 5 == 0 ? 1 : -1)) *
                      (0.7 + 0.3 * t) *
                      (0.5 + 0.5 * (i % 6 == 0 ? 1 : -1)) *
                      (0.7 + 0.3 * t) *
                      (0.5 + 0.5 * (i % 7 == 0 ? 1 : -1)) *
                      (0.7 + 0.3 * t) *
                      (0.5 + 0.5 * (i % 8 == 0 ? 1 : -1)) *
                      (0.7 + 0.3 * t) *
                      (0.5 + 0.5 * (i % 9 == 0 ? 1 : -1)) *
                      (0.7 + 0.3 * t) *
                      (0.5 + 0.5 * (i % 10 == 0 ? 1 : -1)) *
                      (0.7 + 0.3 * t) *
                      (0.5 + 0.5 * (i % 11 == 0 ? 1 : -1)) *
                      (0.7 + 0.3 * t));
      canvas.drawLine(Offset(x, midY), Offset(x, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.t != t;
}
