import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class BottomControls extends StatefulWidget {
  final Player player;
  final bool isPlayerInitialized;
  final VoidCallback onCaptureScreenshot;
  final VoidCallback onMute;
  final bool isMuted;
  final VoidCallback onPlayPrevious;
  final bool canPlayPrevious;
  final VoidCallback onPlayNext;
  final bool canPlayNext;
  final String Function(Duration) formatDuration;
  final VoidCallback startHideTimer;
  final List<int> bookmarks;
  final void Function(int ms) onBookmarkTap;

  const BottomControls({
    Key? key,
    required this.player,
    required this.isPlayerInitialized,
    required this.onCaptureScreenshot,
    required this.onMute,
    required this.isMuted,
    required this.onPlayPrevious,
    required this.canPlayPrevious,
    required this.onPlayNext,
    required this.canPlayNext,
    required this.formatDuration,
    required this.startHideTimer,
    required this.bookmarks,
    required this.onBookmarkTap,
  }) : super(key: key);

  @override
  State<BottomControls> createState() => _BottomControlsState();
}

class _BottomControlsState extends State<BottomControls> {
  bool _isSeeking = false;
  double? _seekBarValue;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.only(bottom: 16.0),
        color: Colors.black.withOpacity(0.35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: widget.onCaptureScreenshot,
                  color: Colors.white,
                  iconSize: 32,
                ),
                IconButton(
                  icon: Icon(
                    widget.isMuted ? Icons.volume_off : Icons.volume_up,
                  ),
                  onPressed: widget.onMute,
                  color: Colors.white,
                  iconSize: 32,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: widget.onPlayPrevious,
                  color: widget.canPlayPrevious ? Colors.white : Colors.white24,
                  iconSize: 36,
                ),
                IconButton(
                  icon: const Icon(Icons.replay_10),
                  onPressed: () => widget.player.seek(
                    widget.player.state.position - const Duration(seconds: 10),
                  ),
                  color: Colors.white,
                  iconSize: 36,
                ),
                StreamBuilder<bool>(
                  stream: widget.player.stream.playing,
                  initialData: widget.player.state.playing,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return IconButton(
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                      ),
                      onPressed: widget.player.playOrPause,
                      color: Colors.white,
                      iconSize: 48,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.forward_10),
                  onPressed: () => widget.player.seek(
                    widget.player.state.position + const Duration(seconds: 10),
                  ),
                  color: Colors.white,
                  iconSize: 36,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: widget.onPlayNext,
                  color: widget.canPlayNext ? Colors.white : Colors.white24,
                  iconSize: 36,
                ),
              ],
            ),
            if (widget.isPlayerInitialized) _buildSeekBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekBar() {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      builder: (context, snapshot) {
        final position = _isSeeking
            ? Duration(milliseconds: (_seekBarValue ?? 0).toInt())
            : (snapshot.data ?? Duration.zero);
        final duration = widget.player.state.duration;
        final durationMs = duration.inMilliseconds.toDouble();
        return Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                widget.formatDuration(position),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.0,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6.0,
                      ),
                    ),
                    child: Slider(
                      value: position.inMilliseconds.toDouble().clamp(
                        0.0,
                        durationMs,
                      ),
                      max: durationMs,
                      onChanged: (value) {
                        setState(() {
                          _seekBarValue = value;
                        });
                      },
                      onChangeStart: (value) {
                        setState(() {
                          _isSeeking = true;
                        });
                      },
                      onChangeEnd: (value) {
                        widget.player.seek(
                          Duration(milliseconds: value.toInt()),
                        );
                        setState(() {
                          _isSeeking = false;
                          _seekBarValue = null;
                        });
                        widget.startHideTimer();
                      },
                    ),
                  ),
                  // Bookmark dots
                  if (widget.bookmarks.isNotEmpty && durationMs > 0)
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: widget.bookmarks.map((ms) {
                              final frac = ms / durationMs;
                              return Positioned(
                                left: (constraints.maxWidth - 8) * frac,
                                top: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: () => widget.onBookmarkTap(ms),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                widget.formatDuration(duration),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
