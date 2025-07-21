import 'package:flutter/services.dart';

class NativeAudioService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.video_player/audio_controls',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.example.video_player/audio_events',
  );

  static Future<void> startAudio(String filePath, int positionMs) async {
    await _channel.invokeMethod('startAudio', {
      'filePath': filePath,
      'position': positionMs,
    });
  }

  static Future<void> pauseAudio() async {
    await _channel.invokeMethod('pauseAudio');
  }

  static Future<void> playAudio() async {
    await _channel.invokeMethod('playAudio');
  }

  static Future<void> nextAudio() async {
    await _channel.invokeMethod('nextAudio');
  }

  static Future<void> previousAudio() async {
    await _channel.invokeMethod('previousAudio');
  }

  static Future<void> seekTo(int positionMs) async {
    await _channel.invokeMethod('seekTo', {'position': positionMs});
  }

  // Listen to playback state changes from native
  static Stream<Map<String, dynamic>> get playbackStateStream => _eventChannel
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event));
}
