import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioScreen extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final bool isAudioPlayerReady;
  final String Function(Duration) formatDuration;
  final VoidCallback onSwitchToVideo;

  const AudioScreen({
    Key? key,
    required this.audioPlayer,
    required this.isAudioPlayerReady,
    required this.formatDuration,
    required this.onSwitchToVideo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: isAudioPlayerReady
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.audiotrack, color: Colors.white, size: 80),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onSwitchToVideo,
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
                StreamBuilder<PlayerState>(
                  stream: audioPlayer.playerStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return IconButton(
                      iconSize: 64,
                      color: Colors.white,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      onPressed: () {
                        if (playing) {
                          audioPlayer.pause();
                        } else {
                          audioPlayer.play();
                        }
                      },
                    );
                  },
                ),
                StreamBuilder<Duration>(
                  stream: audioPlayer.positionStream,
                  builder: (context, snapshot) {
                    final pos = snapshot.data ?? Duration.zero;
                    final total = audioPlayer.duration ?? Duration.zero;
                    return Column(
                      children: [
                        Slider(
                          value: pos.inMilliseconds.toDouble().clamp(
                            0,
                            total.inMilliseconds.toDouble(),
                          ),
                          min: 0,
                          max: total.inMilliseconds.toDouble() > 0
                              ? total.inMilliseconds.toDouble()
                              : 1,
                          onChanged: (value) {
                            audioPlayer.seek(
                              Duration(milliseconds: value.toInt()),
                            );
                          },
                        ),
                        Text(
                          '${formatDuration(pos)} / ${formatDuration(total)}',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    );
                  },
                ),
              ],
            )
          : const CircularProgressIndicator(),
    );
  }
}
